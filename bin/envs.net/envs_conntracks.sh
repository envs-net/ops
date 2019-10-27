#!/usr/bin/env bash

[[ "$EUID" -ne 0 ]] && printf 'Please run as root!\n' && exit 1

log_file='/var/log/envs_conntrack.log'

c_local="$(tail -1 /var/log/conntrack.log | awk '{print $17}')"

lxc_c=( $(for i in $(lxc-ls --active -1); do tail -1 /var/lib/lxc/"$i"/rootfs/var/log/conntrack.log | awk '{print $15}' ; done) )
lxc_sum="$(echo $(printf %d+ ${lxc_c[@]})0 | bc)"

c_sum="$((c_local + lxc_sum))"
echo "conntrack: $c_sum" >> "$log_file"

exit 0
