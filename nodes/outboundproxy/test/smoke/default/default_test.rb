# # encoding: utf-8

# Inspec tests for proxy node

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

describe user('proxy') do
  it { should exist }
end

describe service('ssh') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

describe service('squid') do
  it { should be_installed }
  it { should be_enabled }
end

describe port(3128) do
  it { should be_listening }
  its('processes') {should include 'squid'}
end

# make sure we can sudo
describe command('sudo whoami') do
  its('stdout') { should eq "root\n" }
  its('exit_status') { should eq 0 }
end

# should not be set up to use the proxy ourselves
describe os_env('http_proxy') do
  its('content') { should be_in [nil, ''] }
end
describe os_env('https_proxy') do
  its('content') { should be_in [nil, ''] }
end
describe file('/etc/login.gov/info/http_proxy') do
  it { should exist }
  its('size') { should eq 0 }
end
describe file('/etc/login.gov/info/proxy_server') do
  it { should exist }
  its('size') { should eq 0 }
end
describe file('/etc/environment') do
  its('content') { should_not match(/http_proxy=.../) }
  its('content') { should_not match(/https_proxy=.../) }
end

# test proxy HTTP
describe command('curl -sSf -m 5 --proxy http://localhost:3128 https://checkip.amazonaws.com') do
  its('stderr') { should eq '' }
  its('stdout') { should match(/\A\d+\.\d+\.\d+\.\d+/) }
  its('exit_status') { should eq 0 }
end

# test proxy HTTP denial
describe command('curl -sSf -m 5 --proxy http://localhost:3128 https://denial-test.example.com') do
  its('stderr') { should eq "curl: (22) The requested URL returned error: 403\n" }
  its('stdout') { should eq '' }
  its('exit_status') { should eq 22 }
end

# test proxy port based denial
describe command('curl -sSf -m 5 --proxy http://localhost:3128 https://checkip.amazonaws.com:22') do
  its('stderr') { should eq "curl: (22) The requested URL returned error: 403\n" }
  its('stdout') { should eq '' }
  its('exit_status') { should eq 22 }
end

describe service('filebeat') do
  it { should be_installed }
  it { should be_enabled }
end

# filebeat is harvesting common logs
describe command("grep 'Harvester started for file' /var/log/filebeat/filebea* | awk '{print $NF}' | sort | uniq") do
  its('stdout') { should include '/var/log/alternatives.log' }
  its('stdout') { should include '/var/log/amazon/ssm/amazon-ssm-agent.log' }
  its('stdout') { should include '/var/log/amazon/ssm/errors.log' }
  its('stdout') { should include '/var/log/amazon/ssm/hibernate.log' }
  its('stdout') { should include '/var/log/apport.log' }
  its('stdout') { should include '/var/log/apt/history.log' }
  its('stdout') { should include '/var/log/apt/term.log' }
  its('stdout') { should include '/var/log/audit/audit.log' }
  its('stdout') { should include '/var/log/auth.log' }
# TODO: add once we either test the awsagent update process or the build of this instance takes long
# enough for the awsagent update to occur automatically.
#  its('stdout') { should include '/var/log/awsagent-update.log' }
  its('stdout') { should include '/var/log/awslogs-agent-setup.log' }
  its('stdout') { should include '/var/log/awslogs.log' }
  its('stdout') { should include '/var/log/clamav/clamav.log' }
# TODO: add once we have a test that updates the clamav definitions.
  its('stdout') { should include '/var/log/clamav/freshclam.log' }
  its('stdout') { should include '/var/log/cloud-init-output.log' }
  its('stdout') { should include '/var/log/cloud-init.log' }
  its('stdout') { should include '/var/log/dpkg.log' }
# TODO: perhaps remove this from common since it seems to only be present on ELK instances  
#  its('stdout') { should include '/var/log/fontconfig.log' }
  its('stdout') { should include '/var/log/grubfix.log' }
  its('stdout') { should include '/var/log/kern.log' }
# NOTE: this does not seem to be used on the jumphost
#  its('stdout') { should include '/var/log/landscape/sysinfo.log' }
  its('stdout') { should include '/var/log/mail.log' }
  its('stdout') { should include '/var/log/messages' }
# TODO: add once we have a test for proxy and proxy cache.
#  its('stdout') { should include '/var/log/squid/access.log' }
#  its('stdout') { should include '/var/log/squid/cache.log' }
  its('stdout') { should include '/var/log/sysctlfix.log' }
  its('stdout') { should include '/var/log/syslog' }
  its('stdout') { should include '/var/log/unattended-upgrades/unattended-upgrades-shutdown.log' }
end

# filebeat is harvesting instance specific logs
describe command("grep 'Harvester started for file' /var/log/filebeat/filebea* | awk '{print $NF}' | sort | uniq") do
  its('stdout') { should include '/var/log/squid/access.log' }
  its('stdout') { should include '/var/log/squid/cache.log' }
end

describe service('metricbeat') do
  it { should be_installed }
  it { should be_enabled }
end
