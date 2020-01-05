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

			# matrix
			matrix_dir=/var/lib/lxc/matrix/rootfs/etc/matrix-synapse
			cp "$daemon_cert_root/privkey.pem" "$matrix_dir"/
			cp "$daemon_cert_root/chain.pem" "$matrix_dir"/
			cp "$daemon_cert_root/fullchain.pem" "$matrix_dir"/
			chmod 600 "$matrix_dir"/*.pem
			chown 108:0 "$matrix_dir"/*.pem
			lxc-attach -n matrix -- bash -c "systemctl reload nginx ; systemctl restart matrix-synapse"

			# mail
			lxc-attach -n mail -- bash -c "systemctl reload nginx postfix dovecot"
			# mailinglists
			lxc-attach -n lists -- bash -c "systemctl reload nginx postfix"

			# gitea
			lxc-attach -n gitea -- bash -c "systemctl reload nginx"

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
			# 0x0 / fiche
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
