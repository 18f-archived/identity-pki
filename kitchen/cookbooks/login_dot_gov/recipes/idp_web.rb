if ConfigLoader.load_config_or_nil(node, "basic_auth_password") && node.chef_environment != "prod"
  basic_auth_enabled = true
else
  basic_auth_enabled = false
end

if basic_auth_enabled
  basic_auth_config 'generate basic auth config' do
    password ConfigLoader.load_config(node, "basic_auth_password")
    user_name ConfigLoader.load_config(node, "basic_auth_user_name")
  end
else
  if %w(prod staging).include?(node.chef_environment)
    # When in prod or staging, issue warning that basic auth is disabled
    Chef::Log.warn 'Basic auth disabled'
  else
    # Raise exception if basic auth credentials are missing in other envs
    Chef::Log.fatal 'No basic auth credentials found'
    Chef::Log.fatal 'Only prod and staging may operate without basic auth'
    raise
  end
end

# branch is set by environment/node, otherwise use stages/env
branch_name = node['login_dot_gov']['branch_name'] || "stages/#{node.chef_environment}"
base_dir = '/srv/idp'
deploy_dir = "#{base_dir}/current/public"

# add nginx conf for app server
# TODO: JJG convert security_group_exceptions to hash so we can keep a note in both chef and nginx
#       configs as to why we added the exception.
app_name = 'idp'

domain_name = node.chef_environment == 'prod' ? 'secure.login.gov' : "#{node.chef_environment}.#{node['login_dot_gov']['domain_name']}"

dhparam = ConfigLoader.load_config(node, "dhparam")

# generate a stronger DHE parameter on first run
# see: https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html#Forward_Secrecy_&_Diffie_Hellman_Ephemeral_Parameters
execute "openssl dhparam -out dhparam.pem 4096" do
  creates "/etc/ssl/certs/#{app_name}-dhparam.pem"
  cwd '/etc/ssl/certs'
  notifies :stop, "service[passenger]", :before
  only_if { dhparam == nil }
  sensitive true
end

file '/etc/ssl/certs/dhparam.pem' do
  content dhparam
  not_if { dhparam == nil }
  sensitive true
end

# TODO: Remove this when instance_certificate cookbook is merged
def generate_selfsigned_keypair(subject, valid_days)
  key = OpenSSL::PKey::RSA.new(2048)
  public_key = key.public_key

  cert = OpenSSL::X509::Certificate.new
  cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
  cert.not_before = Time.now - 3600
  cert.not_after = Time.now + 24 * 60 * 60 * valid_days
  cert.public_key = public_key
  cert.serial = Random.rand(2**32-1) + 1
  cert.version = 2

  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = cert
  ef.issuer_certificate = cert
  cert.extensions = [
    ef.create_extension("basicConstraints","CA:FALSE", true),
    ef.create_extension("subjectKeyIdentifier", "hash"),
    ef.create_extension("keyUsage", "keyEncipherment,digitalSignature", true),
  ]
  cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                        "keyid:always,issuer:always")

  cert.sign key, OpenSSL::Digest::SHA256.new

  [key, cert]
end

# Create a self-signed certificate for ALB to talk to. ALB does not verify
# hostnames or care about certificate expiration.
# TODO: Replace this with the instance_certificate cookbook once that's merged.
key_path = "/etc/ssl/private/#{app_name}-key.pem"
cert_path = "/etc/ssl/certs/#{app_name}-cert.pem"

# awkward construction so we don't drain the random pool by constantly
# generating certs
if !File.exist?(key_path) || !File.exist?(cert_path)
  key, cert = generate_selfsigned_keypair("/CN=#{node.name}/O=18F/C=US/", 365)

  file key_path do
    owner 'root'
    group 'root'
    mode '0600'
    content key.to_pem
  end

  file cert_path do
    owner 'root'
    group 'root'
    mode '0644'
    content cert.to_pem
  end
end

template "/opt/nginx/conf/sites.d/login.gov.conf" do
  owner node['login_dot_gov']['system_user']
  notifies :restart, "service[passenger]"
  source 'nginx_server.conf.erb'
  variables({
    app: app_name,
    basic_auth: basic_auth_enabled,
    elb_cidr: node['login_dot_gov']['elb_cidr'],
    security_group_exceptions: JSON.parse(ConfigLoader.load_config(node, "security_group_exceptions")),
    server_aliases: "idp.#{node.chef_environment}.#{node['login_dot_gov']['domain_name']}",
    server_name: domain_name
  })
end

directory "#{deploy_dir}/api" do
  owner node['login_dot_gov']['user']
  recursive true
  action :create
end

template "#{deploy_dir}/api/deploy.json" do
  owner node['login_dot_gov']['user']
  source 'deploy.json.erb'
  variables lazy { ({
    env: node.chef_environment,
    branch: branch_name,
    user: 'chef',
    sha: `cd #{base_dir}/releases/chef ; git rev-parse HEAD`.chomp,
    timestamp: ::Time.new.strftime("%Y%m%d%H%M%S")
  })}
end

execute "/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/bundle exec whenever --update-crontab" do
  cwd "#{base_dir}/current"
  environment({
    'RAILS_ENV' => "production"
  })
  only_if { node.name == "idp1.0.#{node.chef_environment}" } # first idp host
end

# allow other execute permissions on all directories within the application folder
# TODO: check that this is needed
# https://www.phusionpassenger.com/library/admin/nginx/troubleshooting/ruby/#upon-accessing-the-web-app-nginx-reports-a-permission-denied-error
execute "chmod o+X -R /srv"

# need this now that passenger runs as nobody
execute "chown -R #{node[:passenger][:production][:user]} /srv/idp/shared/log"
