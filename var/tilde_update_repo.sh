#!/usr/bin/env bash

cd /var/tilde/admins/ && git pull origin master
cp raw/banned_emails.txt raw/banned_names.txt /var

chown root:www-data /var/banned_emails.txt /var/banned_names.txt
chmod 640 /var/banned_emails.txt /var/banned_names.txt

exit 0
