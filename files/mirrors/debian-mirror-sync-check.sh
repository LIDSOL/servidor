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
# a systemd timer. It works for both, debian and debian-cd mirrors.

# debian mirror

MIRROR_DIRECTORY=/srv/debian

# Set the upstream mirror URL
UPSTREAM_MIRROR=debian.csail.mit.edu
UPSTREAM_MIRROR_URL="https://${UPSTREAM_MIRROR}/debian/project/trace/${UPSTREAM_MIRROR}"

upstream_time=$(curl -s "${UPSTREAM_MIRROR_URL}" | head -n 1)
upstream_time_epoch=$(date -d "${upstream_time}" +%s)

LOCAL_MIRROR="lidsol.fi-b.unam.mx"
local_mirror_time_epoch=0
if [ -f ${MIRROR_DIRECTORY}/project/trace/${UPSTREAM_MIRROR} ]; then
    local_mirror_time=$(cat ${MIRROR_DIRECTORY}/project/trace/${UPSTREAM_MIRROR} | head -n 1)
    local_mirror_time_epoch=$(date -d "${local_mirror_time}" +%s)
fi

if [ $(( $(date +%s) - $upstream_time_epoch )) -gt 7200 ]; then
    if [ $local_mirror_time_epoch -lt $upstream_time_epoch ]; then
        echo "Local mirror is out of date, pulling from upstream mirror"
        cd /home/mirrors/
        /home/mirrors/bin/ftpsync sync:all
    else
        echo "Local mirror is up to date. Upstream date: ${upstream_time}, Local date: ${local_mirror_time}"
    fi
else
    echo "Upstream mirror is old. Does not need to be pulled."
fi

# debian-cd mirror

MIRROR_DIRECTORY=/srv/debian-cd

# Set the upstream mirror URL
UPSTREAM_MIRROR=mirrors.ocf.berkeley.edu
UPSTREAM_MIRROR_URL="https://${UPSTREAM_MIRROR}/debian-cd/project/trace/${UPSTREAM_MIRROR}"

upstream_time=$(curl -s "${UPSTREAM_MIRROR_URL}" | head -n 1)
upstream_time_epoch=$(date -d "${upstream_time}" +%s)

LOCAL_MIRROR="lidsol.fi-b.unam.mx"
local_mirror_time_epoch=0
if [ -f ${MIRROR_DIRECTORY}/project/trace/${UPSTREAM_MIRROR} ]; then
    local_mirror_time=$(cat ${MIRROR_DIRECTORY}/project/trace/${UPSTREAM_MIRROR} | head -n 1)
    local_mirror_time_epoch=$(date -d "${local_mirror_time}" +%s)
fi

if [ $(( $(date +%s) - $upstream_time_epoch )) -gt 7200 ]; then
    if [ $local_mirror_time_epoch -lt $upstream_time_epoch ]; then
        echo "Local cd mirror is out of date, pulling from upstream mirror"
        cd /home/mirrors/
        /usr/bin/rsync --bwlimit=2048 --times --links --hard-links --partial --block-size=8192 --delete --archive rsync://mirrors.ocf.berkeley.edu/debian-cd/ /srv/debian-cd/
    else
        echo "Local cd mirror is up to date. Upstream date: ${upstream_time}, Local date: ${local_mirror_time}"
    fi
else
    echo "Upstream cd mirror is old. Does not need to be pulled."
fi


