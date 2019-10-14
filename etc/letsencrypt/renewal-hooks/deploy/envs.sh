#!/bin/sh

set -e

for domain in $RENEWED_DOMAINS; do
	case $domain in
		envs.net)
			daemon_cert_root=/opt/lxc_ssl/envs.net
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$daemon_cert_root/privkey.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$daemon_cert_root/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$daemon_cert_root/fullchain.pem"
			cat /etc/ssl/certs/envs_dhparam.pem > "$daemon_cert_root/envs_dhparam.pem"
			;;

		envs.sh)
			daemon_cert_root=/opt/lxc_ssl/envs.sh
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$daemon_cert_root/privkey.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$daemon_cert_root/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$daemon_cert_root/fullchain.pem"
			cat /etc/ssl/certs/envs_dhparam.pem > "$daemon_cert_root/envs_dhparam.pem"
			;;

		znc.envs.net)
			daemon_cert_root=/srv/znc/.znc
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$daemon_cert_root/znc.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" >> "$daemon_cert_root/znc.pem"
			cat /etc/ssl/certs/envs_dhparam.pem >> "$daemon_cert_root/znc.pem"
			chown znc "$daemon_cert_root/znc.pem"
			chmod 600 "$daemon_cert_root/znc.pem"
			;;

	esac
done
