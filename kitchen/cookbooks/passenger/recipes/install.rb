#
# Cookbook Name:: passenger
# Recipe:: install

gem_package "passenger/system" do
  gem_binary '/opt/ruby_build/builds/2.3.1/bin/gem'
  not_if "test -e /usr/local/bin/rvm-gem.sh"
  package_name 'passenger'
  version node[:passenger][:production][:version]
end

gem_package "passenger/rvm" do
  gem_binary "/usr/local/bin/rvm-gem.sh"
  only_if "test -e /usr/local/bin/rvm-gem.sh"
  package_name 'passenger'
  version node[:passenger][:production][:version]
end
