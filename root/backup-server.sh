#!/usr/bin/env bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$EUID" -ne 0 ]] && printf 'Please run as root!\n' && exit 1

###
export RESTIC_PASSWORD=';)'

restic='ionice -c0 nice -n-19 restic -r'
rsync='rsync -av --delete --numeric-ids'
###

# LOCAL
BACKUP_DIR='/data/BACKUP'
BACKUP_DIR_LXC='/data/BACKUP_LXC'

# REMOTE ( Backup to rsync.net - CH )
# see: /etc/hosts /root/.ssh/config
BACKUP_HOST='ch_bak'
REMOTE_DIR="$(hostname)"

###

BACKUP_LXC_FULL=''

#RESTIC_LOC_NAME='system lxc'
RESTIC_LOC_NAME='system'

###

DATE="$(date +%Y%m%d)"

### INITIAL Restic Sync ###
for BH in $BACKUP_HOST; do
	for RLN in $RESTIC_LOC_NAME; do
		ssh -q "$BH" [[ ! -d "$REMOTE_DIR"_"$RLN" ]] && restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" init
	done
done

###
test ! -d "$BACKUP_DIR" && mkdir -p "$BACKUP_DIR"
test ! -d "$BACKUP_DIR"_local && mkdir -p "$BACKUP_DIR"_local
test ! -d "$BACKUP_DIR_LXC" && mkdir -p "$BACKUP_DIR_LXC"

#
# Backup LXC-Containers

if [ ! -z "$BACKUP_LXC_FULL" ]; then
	for NAME in $BACKUP_LXC_FULL; do
		cd /var/lib/lxc/"$NAME"/

		lxc-stop -n "$NAME" &
		sleep 2 && lxc-stop -n "$NAME" &
		sleep 1 && lxc-stop -n "$NAME"
			tar --numeric-owner -czvf backup-"$NAME"-"$DATE".tar.gz ./*
		lxc-start -n "$NAME"

		rm "$BACKUP_DIR_LXC"/backup-"$NAME"-*.tar.gz
		mv backup-"$NAME"-"$DATE".tar.gz "$BACKUP_DIR_LXC"/
	done
fi

#
# CUSTOM Backup
#

# Backup local mysql
mysqldump -u root --opt --order-by-primary --all-databases | gzip -c > "$BACKUP_DIR"_local/mysql-dump-$(date +%F.%H%M%S).gz
find "$BACKUP_DIR"_local/mysql-dump-*.gz -maxdepth 1 -type f -mtime +3 -delete

# Backup getwtxt

# Backup bbj


###

sleep 10

#
# System Backup & SYNC
#

dpkg --get-selections | tee "$BACKUP_DIR"_local/pkg.list &>/dev/null
cp -R /etc/apt/sources.list* "$BACKUP_DIR"_local/
apt-key exportall | tee "$BACKUP_DIR"_local/repo.keys &>/dev/null

#
# Restic Backups
for BH in $BACKUP_HOST; do
	$restic sftp:"$BH":"$REMOTE_DIR"_system backup / --exclude={/dev,/media,/mnt,/proc,/run,/sys,/tmp,/var/tmp,/var/lib/lxcfs/cgroup,/data/tmp,/data/BACKUP,/data/BACKUP_LXC,/root/.cache/}
#	$restic sftp:"$BH":"$REMOTE_DIR"_lxc backup "$BACKUP_DIR_LXC"
done


# clear old Backups
CHECKEOM="$(date --date=tomorrow +%d)"
if [ "$CHECKEOM" -eq 01 ]; then
	for BH in $BACKUP_HOST; do
		for RLN in $RESTIC_LOC_NAME; do
			restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" forget --keep-daily 7 --keep-weekly 8 --keep-monthly 24
			restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" prune
		done
	done
fi

#
exit 0
