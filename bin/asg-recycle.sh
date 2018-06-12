#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
. "$(dirname "$0")/lib/common.sh"

# TODO port this whole thing to ruby, it's far too much shell script

# Given an auto-scaling group, schedule a recycle of that group.
usage () {
    cat >&2 <<EOM
usage: $(basename "$0") ENVIRONMENT ROLE [NORMAL_CAPACITY]

Create AWS ASG scheduled actions to recycle instances in an ASG by spinning up
twice as many instances and then spinning back down to the usual number.

By default, spins up 2x instances immediately and spins down to the normal
number after 2x the ASG's health check grace period. The grace period on an ASG
defaults to 5 minutes, so if it hasn't been changed, we will spin down to the
normal number after 10 minutes.

(It is dangerous to spin down instances before the grace period has elapsed
because the ASG ignores health check results during the grace period and could
spin down healthy instances with no replacements available.)

If NORMAL_CAPACITY is set, then treat that as the resting desired capacity
rather than inferring the desired capacity from the current value in AWS.

For example:
    $(basename "$0") qa jumphost

EOM
}

# Calculate ISO timestamp for time DELAY seconds in the future. This would be
# easy to do with GNU date, but we want to work on OS X as well.
calculate_future_time() {
    local delay now future fmt
    delay="$1"
    now="$(date +%s)"
    future=$((now + delay))
    fmt="+%FT%TZ"

    case "$OSTYPE" in
        darwin*)
            # bsd date
            date -u -r "$future" "$fmt"
            ;;
        linux-gnu)
            # gnu date
            date -u --date "@$future" "$fmt"
            ;;
        *)
            echo >&2 "Unknown \$OSTYPE $OSTYPE"
            return 1
            ;;
    esac
}

# get_asg_info ASG_NAME
get_asg_info() {
    run aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$1" 
}

# list_stateful_asgs
list_stateful_asgs() {
    run aws autoscaling describe-auto-scaling-groups --output text \
        | { grep '^TAGS	stateful' || true ; } \
        | cut -f 4
}

# usage: recycle_all_asgs_in_env ENV [RECYCLE_OPTS...]
#
# Call schedule_recycle once for each autoscaling group in ENV. RECYCLE_OPTS
# will be passed directly to schedule_recycle.
#
recycle_all_asgs_in_env() {
    local env asg_name asg_list stateful_asg_list asg_arr
    env="$1"

    shift

    asg_arr=()
    asg_list="$(list_asgs_with_prefix "$env-")"
    stateful_asg_list="$(list_stateful_asgs)"

    for asg_name in $asg_list; do
        if grep -x "$asg_name" <<< "$stateful_asg_list" >/dev/null; then
            echo_yellow "Skipped $asg_name because stateful tag is set"
            continue
        fi
        asg_arr+=("$asg_name")
    done

    echo_green "Will recycle all autoscaling groups in $env:"
    for asg_name in "${asg_arr[@]}"; do
        echo_green "  $asg_name"
    done

    if [ -t 1 ] && [ -t 0 ]; then
        read -r -p "Press enter to continue..."
    fi

    for asg_name in "${asg_arr[@]}"; do
        echo

        echo_green "Starting $asg_name"
        schedule_recycle --skip-zero "$asg_name" "$@"
        echo_green "Done with $asg_name"
    done
}

# list_asgs_with_prefix PREFIX
list_asgs_with_prefix() {
    # There isn't any way to filter ASGs by VPC (since they aren't directly
    # associated with the VPC). So we rely upon our convention that ASG names
    # are supposed to start with the environment name.
    # The autoscaling API also doesn't support filters, so we have do the
    # filtering client side using JMESPath (--query).

    local prefix
    prefix="$1"

    run aws autoscaling describe-auto-scaling-groups --output text \
        --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, \`$prefix\`)].[AutoScalingGroupName]"
}

# schedule_recycle ASG_NAME [DESIRED_CAPACITY]
schedule_recycle() {
    local skip_zero=
    if [ "$1" = "--skip-zero" ]; then
        skip_zero=1
        shift
    fi
    local asg_name="$1"
    local desired_capacity="${2-}"
    local asg_info current_size max_size min_size new_size spindown_delay health_grace_period

    echo_blue "Scheduling ASG recycle of $asg_name"

    asg_info="$(get_asg_info "$asg_name")"

    pyDesiredCapacity="import sys, json;print json.load(sys.stdin)['AutoScalingGroups'][0]['DesiredCapacity']"
    pyMinSize="import sys, json;print json.load(sys.stdin)['AutoScalingGroups'][0]['MinSize']"
    pyMaxSize="import sys, json;print json.load(sys.stdin)['AutoScalingGroups'][0]['MaxSize']"
    pyHealthCheckGracePeriod="import sys, json;print json.load(sys.stdin)['AutoScalingGroups'][0]['HealthCheckGracePeriod']"
    
    current_size=$(echo $asg_info | python -c "$pyDesiredCapacity")
    max_size=$(echo $asg_info | python -c "$pyMaxSize")
    min_size=$(echo $asg_info | python -c "$pyMinSize")
    health_grace_period=$(echo $asg_info | python -c "$pyHealthCheckGracePeriod")

    echo_blue "Current ASG capacity:"
    echo_blue "  desired: $current_size"
    echo_blue "  min:     $min_size"
    echo_blue "  max:     $max_size"
    echo_blue "Health check grace period: ${health_grace_period}s"

    if ((current_size == 0)); then
        local message="current desired size is 0, nothing to recycle"

        # always do nothing if --skip-zero is set and desired count is 0
        if [ -n "$skip_zero" ]; then
            echo_yellow "Warning: skipping $asg_name, $message"
            return
        fi

        # otherwise return error unless we have a new target desired capacity
        if [ -z "$desired_capacity" ]; then
            echo_red "Error: $message"
            return 3
        fi
    fi

    # The health_grace_period reflects the current ASG's health check grace
    # period, which is the interval for new instances during which the ASG will
    # ignore health check results and consider the instance InService even if
    # it is failing ELB health checks.
    #
    # We set our spin-down delay to be 2x the grace period to be extra sure
    # that newly provisioned instances have time to start receiving health
    # checks before we terminate any existing instances.
    #
    # TODO: update docs to reflect recommendations around Lifecycle hooks,
    # which seem to address this safety issue.
    spindown_delay=$((health_grace_period * 2))

    # We use a minimum spin-down delay of 15 minutes
    if ((spindown_delay < 900)); then
        spindown_delay=900
    fi

    if [ -n "$desired_capacity" ]; then
        echo_yellow "Overriding $current_size with desired $desired_capacity"
        current_size="$desired_capacity"
    fi

    new_size="$((current_size * 2))"

    if ((new_size > max_size)); then
        echo_red "Error: cannot spin up $new_size instances, > max $max_size"
        return 1
    fi

    echo_blue "Will increase to $new_size instances immediately"
    echo_blue "Will return to   $current_size instances in ${spindown_delay}s"

    local spindown_time
    spindown_time="$(calculate_future_time "$spindown_delay")"

    run aws autoscaling set-desired-capacity \
        --auto-scaling-group-name "$asg_name" \
        --desired-capacity "$new_size"

    run aws autoscaling put-scheduled-update-group-action \
        --scheduled-action-name RecycleOnce_asg-recycle.sh \
        --auto-scaling-group-name "$asg_name" \
        --start-time "$spindown_time" \
        --desired-capacity "$current_size"

    echo_blue 'Done'
}

ASG_NAME=

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ENV="$1"
ROLE="$2"

if [ $# -ge 3 ]; then
    desired_capacity="$3"
else
    desired_capacity=
fi

ASG_NAME="$ENV-$ROLE"

if [ "$ROLE" = "ALL" ]; then
    recycle_all_asgs_in_env "$ENV" "$desired_capacity"
else
    schedule_recycle "$ASG_NAME" "$desired_capacity"
fi
