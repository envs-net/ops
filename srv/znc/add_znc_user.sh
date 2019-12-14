#!/usr/bin/env bash

[[ "$EUID" -ne "$(id -u znc)" ]] && printf 'Please run as znc!\n' && exit 1

CONF='/srv/znc/.znc/configs/znc.conf'
PID="$(pgrep -u znc znc)"

if [[ -z "$1" ]]; then
    echo -e "Usage: $(basename "$0") [username]"
    exit 1
fi

if awk '/<User/ {print $2}' "$CONF" | grep -iq "$1"; then
    echo -e "znc user \"$1\" already exists"
    exit 1
fi

sed -e "s/NEWUSER/$1/g" /srv/znc/newuser.conf.template >> "$CONF"

[[ -n "$2" ]] && kill -s HUP "$PID"

#
exit 0
