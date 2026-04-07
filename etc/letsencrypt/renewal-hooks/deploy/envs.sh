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

			systemctl reload nginx
			prosodyctl reload

			# jetforce
			jf_dir=/srv/jetforce/ssl
			cat "$RENEWED_LINEAGE/privkey.pem" > "$jf_dir/privkey.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$jf_dir/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$jf_dir/fullchain.pem"
			cat /etc/ssl/certs/envs_dhparam.pem > "$jf_dir/envs_dhparam.pem"
			systemctl restart jetforce

			# mumble
			mum_dir=/etc/mumble/ssl
			cat "$RENEWED_LINEAGE/privkey.pem" > "$mum_dir/privkey.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$mum_dir/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$mum_dir/fullchain.pem"
			cat /etc/ssl/certs/envs_dhparam.pem > "$mum_dir/envs_dhparam.pem"

			chown mumble-server:mumble-server "$mum_dir"/*.pem
			chmod 600 "$mum_dir"/*.pem
			systemctl restart mumble-server

			# mailinglists
			lxc-attach -n lists -- bash -c "systemctl reload nginx postfix"
		;;

		turn.envs.net)
			turn_dir=/etc/coturn
			umask 077
			cat "$RENEWED_LINEAGE/privkey.pem" > "$turn_dir/privkey.pem"
			cat "$RENEWED_LINEAGE/cert.pem" > "$turn_dir/cert.pem"
			cat "$RENEWED_LINEAGE/chain.pem" > "$turn_dir/chain.pem"
			cat "$RENEWED_LINEAGE/fullchain.pem" > "$turn_dir/fullchain.pem"
			chmod 644 "$turn_dir"/*.pem
			systemctl restart coturn
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
