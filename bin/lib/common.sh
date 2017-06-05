#!/bin/bash

# Common shell functions.
# Having a library like this is a surefire sign that you are using too much
# shell and should switch to something like Ruby. But our scripts currently
# pass around a ton of stuff with shell environment variables, so this will
# have to do for the time being.

run() {
    echo >&2 "+ $*"
    "$@"
}

# Prompt the user for a yes/no response.
# Exit codes:
#   0: user entered yes
#   1: user entered no
#   2: STDIN is not a TTY
#
prompt_yn() {
    local prompt ans
    if [ $# -ge 1 ]; then
        prompt="$1"
    else
        prompt="Continue?"
    fi

    if [ ! -t 0 ]; then
        echo >&2 "$prompt [y/n]"
        echo >&2 "prompt_yn: error: stdin is not a TTY!"
        return 2
    fi

    while true; do
        read -r -p "$prompt [y/n] " ans
        case "$ans" in
            Y|y|yes|YES|Yes)
                return
                ;;
            N|n|no|NO|No)
                return 1
                ;;
        esac
    done
}

echo_blue() {
    if [ -t 1 ]; then
        echo -ne "\033[1;34m"
    fi

    echo -n "$*"

    if [ -t 1 ]; then
        echo -ne "\033[m"
    fi
    echo
}
echo_red() {
    if [ -t 1 ]; then
        echo -ne "\033[1;31m"
    fi

    echo -n "$*"

    if [ -t 1 ]; then
        echo -ne "\033[m"
    fi
    echo
}

log() {
    if [ -n "${BASENAME-}" ]; then
        echo >&2 -n "$BASENAME: "
    fi
    echo >&2 "$*"
}

get_terraform_version() {
    # checkpoint is the hashicorp thing that phones home to check versions
    CHECKPOINT_DISABLE=1 run terraform --version | head -1 | cut -d' ' -f2
}

# usage: check_terraform_version SUPPORTED_VERSION...
#
# e.g. check_terraform_version v0.8.* v0.9.*
#
# Check whether the current version of terraform (as reported by terraform
# --version) is in the allowed list passed as arguments. Return 0 if so,
# otherwise return 1.
check_terraform_version() {
    current_tf_version="$(get_terraform_version)"

    if [ $# -eq 0 ]; then
        echo_red >&2 \
            "error: no supported versions passed to check_terraform_version"
        return 2
    fi

    for version in "$@"; do
        # version is expected to be a pattern
        # shellcheck disable=SC2053
        if [[ $current_tf_version == $version ]]; then
            echo "Terraform version $current_tf_version is supported"
            return
        fi
    done

    echo_red >&2 "Terraform version $current_tf_version is not supported"
    echo_red >&2 "Expected versions: $*"

    echo >&2 "Tip: you can use \`brew switch terraform VERSION\` to switch to"
    echo >&2 "a target installed version of terraform with homebrew."

    return 1
}
