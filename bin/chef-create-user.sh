#!/bin/bash
# shellcheck disable=SC1090

set -eu

. "$(dirname "$0")/lib/common.sh"

usage() {
    cat >&2 <<EOM
usage: $(basename "$0") USERNAME ENVIRONMENT [CHEF_SSH_HOST]

Create a chef user for use with knife and download relevant keys to
\$TF_VAR_chef_home (default ~/.chef).

Arguments:

    USERNAME        User to create in chef (i.e. \$GSA_USERNAME)
    ENVIRONMENT     The environment
    CHEF_SSH_HOST   What to pass to SSH to get to the chef host. Defaults to
                    chef.ENVIRONMENT.login.gov.

Examples:

    # create chef user in qa using default SSH options
    $0 $USER qa

    # create chef user in qa connecting via ubuntu user
    $0 $USER qa ubuntu@chef.qa.login.gov


Sample ~/.ssh/config that may be helpful, which sets up automatic jumphost use
for direct SSH without needing ssh -A:

    Host jumphost.*.login.gov
    #User ubuntu
    User myusername
    LocalForward 3128 localhost:3128
    #SendEnv AWS_*

    host *.*.login.gov !jumphost.*
    User myusername
    proxycommand bash -c 'set -x;  ssh "%r@jumphost.\$(cut -f2 -d. <<< "%h").login.gov" -W "\$(cut -f1 -d. <<< "%h"):%p"'
EOM
}

# Log all calls to SSH
ssh() {
    echo >&2 "+ ssh $*"
    command ssh "$@"
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

username="$1"
environment="$2"

if [ $# -ge 3 ]; then
    ssh_host="$3"
else
    ssh_host="chef.$environment.login.gov"
fi

echo_blue >&2 "Setting up chef user for $username in $environment ($ssh_host)"

if ! grep -w "$environment" <<< "$ssh_host" >/dev/null; then
    echo_red "The env '$environment' doesn't appear in ssh host '$ssh_host'"
    prompt_yn "Are you sure this is right?"
fi

echo_blue >&2 "Loading environment"
echo >&2 "+ . $(dirname "$0")/load-env.sh $environment $username"
. "$(dirname "$0")/load-env.sh" "$environment" "$username"

echo >&2 "Checking that some needed env variables exist"
# shellcheck disable=SC2154
cat <<EOM
TF_VAR_chef_home: $TF_VAR_chef_home
TF_VAR_chef_id_key_path: $TF_VAR_chef_id_key_path
TF_VAR_chef_info: $TF_VAR_chef_id_key_path
TF_VAR_chef_databag_key_path: $TF_VAR_chef_databag_key_path
EOM

users="$(ssh "$ssh_host" sudo chef-server-ctl user-list)"
if grep "$username" <<< "$users" >/dev/null; then
    echo_blue >&2 "Looks like user $username already exists"
    # ensure key exists
    cat "$TF_VAR_chef_id_key_path" > /dev/null
else
    assert_file_not_exists "$TF_VAR_chef_id_key_path"

    # shellcheck disable=SC2154,SC2029
    ssh "$ssh_host" sudo chef-server-ctl user-create \
        "$username" "$TF_VAR_chef_info" > "$TF_VAR_chef_id_key_path"

    echo_blue >&2 "Created new chef user and saved key to local $TF_VAR_chef_id_key_path"
fi

# shellcheck disable=SC2029
ssh "$ssh_host" sudo chef-server-ctl org-user-add login-dev "$username" --admin

validator_path="$TF_VAR_chef_home/$environment-login-dev-validator.pem"
ssh "$ssh_host" sudo cat /root/login-dev-validator.pem > "$validator_path"

echo_blue >&2 "Downloaded login-dev-validator.pem to $validator_path"

if [ "$(ssh "$ssh_host" whoami)" = "ubuntu" ]; then
    echo_yellow >&2 "Remote user is ubuntu. Will not set up knife or" \
        "download config data bags."
    echo_yellow >&2 "You may wish to run bin/setup-knife.sh at some point"

    echo_green >&2 "All done!"
    exit
fi

if ssh "$ssh_host" test -e .chef/knife.rb; then
    echo >&2 "Knife appears to be already set up on chef server"
else
    echo_blue >&2 "Running setup-knife.sh to set up knife on chef server"

    run "$(dirname "$0")/setup-knife.sh" "$username" "$environment" "$ssh_host" \
        "$TF_VAR_chef_home"

    echo_blue >&2 "Done setting up knife on chef server"
fi

echo_blue >&2 "Downloading config data bag from chef server using knife"

# make sure config data bag exists
ssh "$ssh_host" knife data bag show config

assert_file_not_exists "$TF_VAR_chef_databag_key_path"

ssh "$ssh_host" knife data bag show config app -Fj \
    > "$TF_VAR_chef_databag_key_path"

echo_blue >&2 "Downloaded config data bag to $TF_VAR_chef_databag_key_path"

echo_green >&2 "All done!"

echo_blue >&2 "You may wish to set up knife on the jumphost"

if [ "$ssh_host" = "chef.$environment.login.gov" ]; then
    echo_blue >&2 "$(dirname "$0")/setup-knife.sh \"$username\"" \
        "\"$environment\" \"jumphost.$environment.login.gov\"" \
        "\"$TF_VAR_chef_home\""
fi
