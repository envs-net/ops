#!/bin/bash
# updates all additional prosody modules installed via prosodyctl

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

MODULES=(
    mod_auth_cyrus
    mod_cloud_notify_encrypted
    mod_cloud_notify_extensions
    mod_cloud_notify_filters
    mod_cloud_notify_priority_tag
    mod_csi_battery_saver
    mod_default_bookmarks
    mod_http_altconnect
    mod_muc_moderation
    mod_muc_notifications
    mod_ping_muc
    mod_reload_modules
    mod_s2s_keepalive
    mod_track_muc_joins
)

echo "=== Starting Prosody module update ==="

for mod in "${MODULES[@]}"; do
    echo "Updating $mod ..."
    prosodyctl install --server=https://modules.prosody.im/rocks/ "$mod"
    if [ $? -ne 0 ]; then
        echo "⚠️  Error updating $mod"
    else
        echo "✅ $mod updated successfully"
    fi
done

echo "=== All modules updated. Restarting Prosody ==="
systemctl restart prosody

echo "=== Done. Installed modules: ==="
prosodyctl list
