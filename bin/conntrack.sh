#!/usr/bin/env bash

[[ "$EUID" -ne 0 ]] && printf 'Please run as root!\n' && exit 1

f="/var/log/conntrack.log"

d="$(date)"
n1="$(/sbin/sysctl -a 2>&1 | grep -i 'net.netfilter.nf_conntrack_max')"
n2="$(/sbin/sysctl -a 2>&1 | grep -i 'net.nf_conntrack_max')"
c="$(/sbin/sysctl net.netfilter.nf_conntrack_count)"

echo "conntrack: $d: $n1, $n2, $c" >> $f

#
exit 0
