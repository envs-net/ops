#!/bin/bash
# Updates all additional Prosody modules installed via prosodyctl (LuaRocks)

set -euo pipefail
IFS=$'\n\t'

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root!"
    exit 1
fi

MODULES=(
    mod_auth_cyrus
    mod_cloud_notify_encrypted
    mod_cloud_notify_extensions
    mod_cloud_notify_filters
    mod_cloud_notify_priority_tag
    mod_csi_battery_saver
    mod_default_bookmarks
    mod_firewall
    mod_http_altconnect
    mod_measure_active_users
    mod_muc_moderation
    mod_muc_notifications
    mod_pastebin
    mod_ping_muc
    mod_pubsub_serverinfo
    mod_reload_modules
    mod_muc_rtbl
    mod_muc_offline_delivery
    mod_s2s_bidi
    mod_s2s_keepalive
    mod_sasl2
    mod_sasl2_bind2
    mod_sasl2_sm
    mod_sasl2_fast
    mod_sasl_ssdp
    mod_track_muc_joins
)

echo "=== Starting Prosody module update ==="

for mod in "${MODULES[@]}"; do
    echo -n "Updating $mod ... "
    if prosodyctl install --server=https://modules.prosody.im/rocks/ "$mod"; then
        echo "✅ success"
    else
        echo "⚠️ failed"
    fi
done

echo "=== All updates attempted. Restarting Prosody ==="
#systemctl restart prosody && echo "✅ Prosody restarted successfully" || echo "⚠️ Failed to restart Prosody"

echo "=== Installed modules: ==="
prosodyctl list
