# set this so that we listen on 8443
default['apache']['listen'] = [8443]

# get a more modern version of terraform
default['terraform']['version'] = '0.8.2'

# need this for jenkins to be able to get access to chef creds
default['authorization']['sudo']['include_sudoers_d'] = true

# list of users that we allow in
#default['identity-jenkins']['users'] = ['user1']
#default['identity-jenkins']['admins'] = ['admin1','admin2']

# list of plugns that we need to install
default['identity-jenkins']['jenkns-plugins'] = [
  'git',
  'ssh',
  'promoted-builds',
  'envinject',
  'credentials',
  'credentials-binding',
  'plain-credentials',
  'ssh-agent',
  'matrix-auth',
  'parameterized-trigger',
  'chef-identity',
  'reverse-proxy-auth-plugin',
  'rebuild'
]
