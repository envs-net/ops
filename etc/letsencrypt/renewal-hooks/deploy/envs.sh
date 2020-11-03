#!/bin/sh
# DO NOT TOUCH IT HERE SEE GIT REPO 'envs/ops'

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

#			rsync -av "$daemon_cert_root" root@srv01.envs.net:/opt/ssl_certs/
#			ssh root@srv01.envs.net bash -c "/opt/sync_certs.sh"

			# mail
			# has a own letencrypt cert in container!

			# mailinglists
			lxc-attach -n lists -- bash -c "systemctl reload nginx postfix"

			# gitea
			lxc-attach -n gitea -- bash -c "systemctl reload nginx"

			# drone-ci
			lxc-attach -n drone -- bash -c "systemctl reload nginx"

			# codimd
			lxc-attach -n codimd -- bash -c "systemctl reload nginx"

			# searx
			lxc-attach -n searx -- bash -c "systemctl reload nginx"

			# cryptad
			lxc-attach -n pad -- bash -c "systemctl reload nginx"

			# tt-rss
			lxc-attach -n rss -- bash -c "systemctl restart apache2"

			# privatebin
			lxc-attach -n pb -- bash -c "systemctl restart apache2"
		;;

		envs.sh)
			daemon_cert_root=/opt/lxc_ssl/envs.sh
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$daemon_cert_root/privkey.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$daemon_cert_root/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$daemon_cert_root/fullchain.pem"
			cat /etc/ssl/certs/envs_dhparam.pem > "$daemon_cert_root/envs_dhparam.pem"

			# 0x0
			lxc-attach -n null -- bash -c "systemctl reload nginx"
		;;

		znc.envs.net)
			daemon_cert_root=/srv/znc/.znc
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$daemon_cert_root/znc.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" >> "$daemon_cert_root/znc.pem"
			cat /etc/ssl/certs/envs_dhparam.pem >> "$daemon_cert_root/znc.pem"
			chown znc "$daemon_cert_root/znc.pem"
			chmod 600 "$daemon_cert_root/znc.pem"
			systemctl restart znc
		;;

	esac
done
