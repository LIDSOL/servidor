#!/bin/bash
# This script checks the status of the upstream Debian mirror.
# Specifically, it checks the status file in the project/trace/
# directory in the upstream mirror and in the local mirror,
# and checks the following conditions:
#
# - If the pull from upstream mirror is less than 2 hours old,
#   then the mirror is considered up-to-date, and no action is taken.
# - If the pull from upstream mirror is older than 2 hours old, and
#   the local mirror is older than the upstream mirror, then a new
#   pull is initiated.
# - If the pull from upstream mirror is older than 2 hours old, and
#   the local mirror is newer than the upstream mirror, then the
#   local mirror is considered up-to-date, and no action is taken.
#
# This script is intended to be run repeatedly by a cron job or
# a systemd timer.

LOCAL_MIRROR="lidsol.fi-b.unam.mx"
MIRROR_DIRECTORY=/srv/debian

# Set the upstream mirror URL
UPSTREAM_MIRROR=debian.csail.mit.edu
UPSTREAM_MIRROR_URL="https://${UPSTREAM_MIRROR}/debian/project/trace/${UPSTREAM_MIRROR}"

function get_upstream_time() {
    curl -s "${UPSTREAM_MIRROR_URL}" | head -n 1
}

function get_local_time() {
    if [ -f ${MIRROR_DIRECTORY}/project/trace/${LOCAL_MIRROR} ]; then
        cat ${MIRROR_DIRECTORY}/project/trace/${LOCAL_MIRROR} | head -n 1
    else
        echo "1970-01-01 00:00:00 UTC"
    fi
}

function should_pull() {
    local_mirror_time=$1
    upstream_time=$2
    current_time=$3

    # Get epoch time for each date
    local_mirror_time_epoch=$(date -d "$local_mirror_time" +%s)
    upstream_time_epoch=$(date -d "$upstream_time" +%s)
    current_time_epoch=$(date -d "$current_time" +%s)

    # If it has a difference of more than 4 hours between the local mirror and the upstream mirror,
    # then the local mirror is considered out of date for a long time
    if [ $local_mirror_time_epoch -lt $(($upstream_time_epoch - 14400)) ]; then
        echo "The existing mirror is out of date for a long time" >&2
        echo "true"
        return
    fi

    # If the local mirror is older than the upstream mirror, then the local mirror
    # and the upstream mirror synced more than 2 hours ago, the local mirror is considered out of date
    if [ $local_mirror_time_epoch -lt $upstream_time_epoch ] && [ $upstream_time_epoch -lt $(($current_time_epoch - 7200)) ]; then
        echo "The local mirror is older than the upstream mirror" >&2
        echo "true"
    else
        echo "false"
    fi
}

# If this script is called with the --test flag, then it does not perform any actions
if [ "$1" == "--test" ]; then
    exit 0
fi

# Assign functions output to variables so they share the same value for the whole script
upstream_time=$(get_upstream_time)
local_time=$(get_local_time)
current_time=$(date -u)

if [ $(should_pull "$local_time" "$upstream_time" "$current_time") == "true" ]; then
    echo "Local mirror is out of date, pulling from upstream mirror. Upstream date: $upstream_time, Local date: $local_time - current date: $current_time"
    cd ${MIRROR_DIRECTORY}
    /home/mirrors/bin/ftpsync sync:all
else
    echo "Local mirror is up to date. Upstream date: $upstream_time, Local date: $local_time - current date: $current_time"
fi