#!/usr/bin/env bash

cd /var/tilde/admins/ && git pull origin master
cp raw/banned_emails.txt raw/banned_names.txt /var

chown www-data:root /var/banned_emails.txt /var/banned_names.txt
chmod 600 /var/banned_emails.txt /var/banned_names.txt

exit 0
