#!/usr/bin/env bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1
[ "$(ps ax | grep -ce 'restic\|ch_bak:core.envs.net')" -gt 1 ] && printf 'Backup runs already!\n' && exit 1

###

export RESTIC_PASSWORD=';)'

restic='nice -n19 ionice -n7 restic -r'
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

##RESTIC_LOC_NAME='system lxc'
RESTIC_LOC_NAME='system'

###

DATE="$(date +%Y%m%d)"

### INITIAL Restic Sync ###
for BH in $BACKUP_HOST; do
	for RLN in $RESTIC_LOC_NAME; do
		ssh -q "$BH" [ ! -d "$REMOTE_DIR"_"$RLN" ] && restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" init
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
mysqldump -u root --opt --order-by-primary --all-databases | gzip -c > /var/db-backups/mysql-dump-$(date +%F.%H%M%S).gz

# Backup local pgsql
## TODO
#pg_dumpall -U postgres | gzip -c > /var/db-backups/pgsql-dump-$(date +%F.%H%M%S).gz

# Backup git
lxc-attach -n gitea -- bash -c "sudo -Hiu git nice -n19 ionice -n7 /usr/local/bin/gitea dump -c /etc/gitea/app.ini"

# Backup matrix
lxc-attach -n matrix -- bash -c "sudo -Hiu postgres nice -n19 ionice -n7 pg_dump -F t matrix > /var/db-backups/matrix.tar"

# Backup pleroma
lxc-attach -n pleroma -- bash -c "sudo -Hiu postgres nice -n19 ionice -n7 pg_dump -F t pleroma > /var/db-backups/pleroma.tar"

# Backup ttrss
lxc-attach -n rss -- bash -c "nice -n10 ionice -n7 mysqldump -u root ttrss | nice -n19 ionice -n7 gzip -c > /var/db-backups/ttrss.gz"

###

sleep 10

#
# System Backup & SYNC
#

dpkg --get-selections | tee "$BACKUP_DIR"_local/pkg.list &>/dev/null
cp -r /etc/apt/sources.list* "$BACKUP_DIR"_local/
apt-key exportall | tee "$BACKUP_DIR"_local/repo.keys &>/dev/null

#
# Restic Backups
#
lp='/var/lib/lxc/*/rootfs'
exclude_lxc="$lp/dev,$lp/media,$lp/mnt,$lp/proc,$lp/run,$lp/sys,$lp/tmp,$lp/var/tmp"

for BH in $BACKUP_HOST; do
	eval $restic sftp:"$BH":"$REMOTE_DIR"_system backup / --exclude=\{/dev,/media,/mnt,/proc,/run,/sys,/tmp,/root/.cache/,/var/tmp,/var/lib/lxcfs/cgroup,/data/tmp,/data/BACKUP,/data/BACKUP_LXC,$exclude_lxc\}
##	$restic sftp:"$BH":"$REMOTE_DIR"_lxc backup "$BACKUP_DIR_LXC"
done


#
# clear old Backups
# remote
CHECKEOM="$(date --date=tomorrow +%d)"
if [ "$CHECKEOM" -eq 01 ]; then
	for BH in $BACKUP_HOST; do
		for RLN in $RESTIC_LOC_NAME; do
			restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" forget --keep-daily 1 --keep-weekly 4 --keep-monthly 1
			restic -r sftp:"$BH":"$REMOTE_DIR"_"$RLN" prune
		done
	done
fi

# local
rm -f /var/db-backups/mysql-dump*.gz
#rm -f /var/db-backups/pgsql-dump*.gz
rm -f /var/lib/lxc/gitea/rootfs/srv/git/gitea-dump*.zip
rm -f /var/lib/lxc/matrix/rootfs/var/db-backups/matrix.tar
rm -f /var/lib/lxc/pleroma/rootfs/var/db-backups/pleroma.tar
rm -f /var/lib/lxc/rss/rootfs/var/db-backups/ttrss.gz

#
exit 0
