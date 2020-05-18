#!/usr/bin/env bash

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

test ! -f /var/www/envs.net/stats/ && mkdir -p /var/www/envs.net/stats/

{
	zcat /var/log/nginx/other_vhosts_access.*.gz
	cat /var/log/nginx/other_vhosts_access.log.1
	cat /var/log/nginx/other_vhosts_access.log
} | awk '$8=$1$8' | /usr/bin/nice -n19 goaccess -a \
	-o /var/www/envs.net/stats/index.html \
	--ignore-panel=HOSTS \
	--ignore-panel=KEYPHRASES \
	--log-format=VCOMBINED - \
	--html-prefs='{"theme":"darkGray"}'

exit 0
