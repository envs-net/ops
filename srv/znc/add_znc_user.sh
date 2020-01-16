#!/usr/bin/env bash

if [ "$(id -u)" -ne "$(id -u znc)" ]; then
	printf 'Please run as znc!\n' ; exit 1
fi

CONF='/srv/znc/.znc/configs/znc.conf'
PID="$(pgrep -u znc znc)"

if [ -z "$1" ]; then
    echo -e "Usage: $(basename "$0") [username]" ; exit 1
fi

if grep -Fxq "<User $2>" "$CONF"; then
    echo -e "znc user \"$1\" already exists" ; exit 1
fi

sed -e "s/NEWUSER/$1/g" /srv/znc/newuser.conf.template >> "$CONF"

[ -n "$2" ] && kill -s HUP "$PID"

exit 0
