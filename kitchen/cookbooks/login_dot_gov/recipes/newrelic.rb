node.default['newrelic']['server_monitoring']['hostname'] = node['set_fqdn']
include_recipe "newrelic"

license = Chef::EncryptedDataBagItem.load('config', 'app')["#{node.chef_environment}"]['newrelic_license_key']

execute 'nrsysmond-config --set license_key=' do
  action :nothing
  sensitive true
  command "nrsysmond-config --set license_key=#{license}"
  subscribes :run,  'template[/etc/newrelic/nrsysmond.cfg]', :immediately
end
