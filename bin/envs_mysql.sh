#!/usr/bin/env bash

CMD="$1"
DB="$2"
BACKUP_DIR="/home/$USER/backup"

print_usage() {
	printf 'envs.net | mysql backup & restore\n\n'
	printf 'Usage: %s\n\t backup\t\t\t - backup your default user database (%s)\n' "$(basename "$0")" "$USER"
	printf '\t backup <db_name>\t - backup database\n'
	printf '\t restore\t\t - restore your latest user database\n'
	printf '\t restore <db_name>\t - restore database\n'
}

backup() {
	[ -z "$DB" ] && DB="$USER"
	test ! -d "$BACKUP_DIR" && mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"

	mysqldump -u "$USER" "$DB" -p | gzip -c > "$BACKUP_DIR"/db_"$(date +%F.%H%M%S)".sql.gz
	find "$BACKUP_DIR"/db_*.gz -maxdepth 1 -type f -mtime +7 -delete
}

restore() {
	if [ -z "$DB" ]; then
		latest=''; for f in "$BACKUP_DIR"/db_*.gz; do [ "$f" -nt "$latest" ] && latest="$f"; done
		[ -z "$latest" ] && printf 'no restore file found in %s!\n' "$BACKUP_DIR" && exit 0
		DB="$latest"
		gunzip < "$DB" | mysql -u "$USER" "$USER" -p
	else
		gunzip < "$BACKUP_DIR"/"$DB" | mysql -u "$USER" "$DB" -p
	fi
}

[ $# -lt 1 ] && print_usage && exit 1

case "$CMD" in
	backup*)	backup;;

	restore*)	restore;;

	*) print_usage;;
esac

#
exit 0
