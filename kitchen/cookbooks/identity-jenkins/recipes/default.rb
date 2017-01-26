#
# Cookbook Name:: identity-jenkins
# Recipe:: default
#

# install cert
acme_selfsigned "#{node.cloud_v2.public_ipv4}" do
  crt     "/etc/ssl/jenkins.#{node.chef_environment}.login.gov.crt"
  key     "/etc/ssl/jenkins.#{node.chef_environment}.login.gov.key"
  notifies :restart, 'service[apache2]'
end

# set up apache to proxy to jenkins app
include_recipe 'apache2'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_proxy'
include_recipe 'apache2::mod_proxy_http'
include_recipe 'apache2::mod_headers'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_authn_core'
include_recipe 'apache2::mod_authn_file'
include_recipe 'apache2::mod_authz_core'
include_recipe 'apache2::mod_authz_user'
include_recipe 'apache2::mod_auth_basic'

template '/etc/apache2/sites-available/jenkinsproxy.conf' do
  source 'jenkinsproxy.conf.erb'
  notifies :restart, 'service[apache2]'
end

template '/etc/apache2/htpasswd' do
  source 'htpasswd.erb'
  variables ({
    :users => node['identity-jenkins']['users'] | node['identity-jenkins']['admins']
  })
end

apache_site 'jenkinsproxy'

# install jenkins
jenkinstmp = '/var/lib/jenkinstmp'
node.default['jenkins']['master']['jvm_options'] = "-Djava.io.tmpdir=#{jenkinstmp}"
#node.default['jenkins']['master']['version'] = "2.35"
directory jenkinstmp do
  owner 'root'
  group 'root'
  mode '1777'
end
package 'openjdk-7-jre-headless'
include_recipe 'jenkins::master'
file '/var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion' do
  content '2.3'
  owner 'jenkins'
  group 'jenkins'
  action :create_if_missing
end

# add plugins that we need to run our jobs
node['identity-jenkins']['jenkns-plugins'].each do |plugin|
  jenkins_plugin plugin do
    notifies :restart, 'service[jenkins]'
  end
end

# XXX do it again to get upgrades?
execute 'echo restarting jenkins' do
  notifies :restart, 'service[jenkins]', :immediately
end
directory "#{node[:jenkins][:master][:home]}/updates" do
  owner "#{node[:jenkins][:master][:user]}"
  group "#{node[:jenkins][:master][:user]}"
  action :create
end
execute "update jenkins update center" do
  command "wget http://updates.jenkins-ci.org/update-center.json -qO- | sed '1d;$d'  > #{node[:jenkins][:master][:home]}/updates/default.json"
  user "#{node[:jenkins][:master][:user]}"
  group "#{node[:jenkins][:master][:user]}"
  creates "#{node[:jenkins][:master][:home]}/updates/default.json"
end

# Install all plugins and restart once
jenkins_command "install-plugin #{node['identity-jenkins']['jenkns-plugins'].join(' ')}"
jenkins_command "safe-restart"

# set ssh key up for git access
directory '/var/lib/jenkins/.ssh' do
  user  'jenkins'
  group 'jenkins'
  mode  '0700'
end

file '/var/lib/jenkins/.ssh/id_rsa.pub' do
  content Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_ssh_pubkey']
  user  'jenkins'
  group 'jenkins'
  mode  '0700'
end

file '/var/lib/jenkins/.ssh/id_rsa' do
  content Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_ssh_privkey']
  user  'jenkins'
  group 'jenkins'
  mode  '0700'
end

file '/root/.ssh/id_rsa.pub' do
  content Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_equifax_gem_pubkey']
  user  'root'
  group 'root'
  mode  '0600'
  subscribes :create, "execute[/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/bundle install]", :before
end

file '/root/.ssh/id_rsa' do
  content Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_equifax_gem_privkey']
  user  'root'
  group 'root'
  mode  '0600'
  subscribes :create, "execute[/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/bundle install]", :before
end

# Jenkins seems to need a restart here, or the creds won't apply
execute 'echo restarting jenkins' do
  notifies :restart, 'service[jenkins]', :immediately
end

jenkins_private_key_credentials 'github-deploy' do
  id          'github-deploy'
  description 'Deploy key for pulling from git'
  private_key Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_ssh_privkey']
end

ssh_known_hosts_entry 'github.com'

# set up ssh key up for being able to do 'cap deploy'
deploykey_path = File.join(Chef::Config[:file_cache_path], 'id_rsa_deploy')
execute 'generate deploy ssh key' do
  creates deploykey_path
  command "ssh-keygen -t rsa -q -f #{deploykey_path} -P \"\""
end

ruby_block 'set jenkins deploy pubkey attribute' do
  block do 
    node.default['jenkins_deploy_pubkey'] = File.read("#{deploykey_path}.pub").chomp
  end
end

jenkins_private_key_credentials 'deploy' do
  id          'deploy'
  description 'Deploy key for capistrano'
  private_key Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['jenkins_ssh_privkey']
end

# set up terraform on the host
include_recipe 'terraform'

# terraform needs this dir to be writable
directory '/usr/local/src' do
  mode '1777'
end

# set up AWS cli
package 'python2.7'
package 'python-pip'
execute 'pip install awscli'

# configure jenkins
template '/var/lib/jenkins/config.xml' do
  owner 'jenkins'
  group 'jenkins'
  source 'config.xml.erb'
  variables ({
    :admins => node['identity-jenkins']['admins'],
    :users => node['identity-jenkins']['users']
  })
  notifies :restart, 'service[jenkins]'
end

# jenkins jobs here
# set up env
template File.join(Chef::Config[:file_cache_path], 'login-env.sh') do
  source 'login-env.sh.erb'
  variables ({
    :build_env => Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['build_env']
  })
  mode '0755'
end

xml = File.join(Chef::Config[:file_cache_path], 'infrastructure-config.xml')
template xml do
  source 'infrastructure-config.xml.erb'
end
jenkins_job "terraform" do
  config xml
end

gem_package 'berkshelf' do
  gem_binary "/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/gem"
end

xml = File.join(Chef::Config[:file_cache_path], 'chefclient-config.xml')
template xml do
  source 'chefclient-config.xml.erb'
end
jenkins_job "chef" do
  config xml
end

package 'postgresql-client-9.3'
package 'postgresql-server-dev-9.3'
gem_package 'pg' do
  options('-- --with-pg-config=/usr/bin/pg_config --with-pg-lib=/usr/lib/')
  gem_binary "/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/gem"
end

# branch is 'master'(default) when env is dev, otherwise use stages/env 
branch_name = (node.chef_environment == 'dev' ? node['login_dot_gov']['branch_name'] : "stages/#{node.chef_environment}")
idp_path = File.join(Chef::Config[:file_cache_path], 'identity-idp')
git idp_path do
  repository 'https://github.com/18F/identity-idp'
  revision branch_name
end

execute 'ssh-keyscan -H github.com > /etc/ssh/ssh_known_hosts'

execute "/opt/ruby_build/builds/#{node['login_dot_gov']['ruby_version']}/bin/bundle install" do
  cwd idp_path
end

codexml = File.join(Chef::Config[:file_cache_path], 'code-config.xml')
template codexml do
  source 'code-config.xml.erb'
end
jenkins_job "code" do
  config codexml
end

codexml = File.join(Chef::Config[:file_cache_path], 'stack-config.xml')
template codexml do
  source 'stack-config.xml.erb'
end
jenkins_job "Deploy stack to #{node.chef_environment}" do
  config codexml
end
