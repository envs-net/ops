-- ======================
-- GLOBAL
-- ======================

admins = { "creme@envs.net" }

network_backend = "epoll";
use_libunbound = true

s2s_secure_auth = true
c2s_require_encryption = true
s2s_require_encryption = true
s2s_insecure_domains = { }
s2s_keepalive_interval = 60

c2s_direct_tls_ports = { 5223 }
s2s_direct_tls_ports = { 5270 }

http_interfaces = { "127.0.0.1", "::1" }
http_ports = { 5280 }
https_interfaces = {}
trusted_proxies = { "127.0.0.1", "::1" }

http_cors_override = {
	["*"] = { "GET"; "POST"; "OPTIONS" }
}

ssl = {
	key = "/etc/letsencrypt/live/envs.net/privkey.pem";
	certificate = "/etc/letsencrypt/live/envs.net/fullchain.pem";
	dhparam = "/etc/ssl/certs/envs_dhparam.pem";
	protocol = "tlsv1_2+";
	ciphers = "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256:ECDHE+AESGCM:ECDHE+CHACHA20";
	prefer_server_ciphers = true;
	options = { "no_compression", "no_ticket" };
}

limits = {
	c2s = { rate = "30kb/s"; burst = "200kb"; };
	s2s = { rate = "100kb/s"; burst = "256kb"; };
}
unlimited_jids = { "creme@envs.net" }

-- ======================
-- MODULES ENABLED
-- ======================

modules_enabled = {
	-- Core
	"disco";
	"roster";
	"saslauth";
	"sasl2";
	"sasl2_bind2";
	"sasl2_sm";
	"sasl2_fast";
	"sasl_ssdp";
	"tls";
	"http";

	-- Modern XMPP
	"carbons";
	"smacks";
	"pep";
	"blocklist";
	"bookmarks";
	"vcard4";
	"vcard_legacy";
	"websocket";

	-- Mobile / Push
	"cloud_notify";
	"cloud_notify_extensions";
	"csi_battery_saver";

	-- Archive
	"mam";

	-- Security / Stability
	"limits";
	"ping";
	"ping_muc";
	"s2s_bidi";
	"s2s_keepalive";

	-- Admin
	"admin_shell";
	"admin_adhoc";

	-- others
	"account_activity";
	"time";
	"uptime";
	"version";

	"reload_modules";
	"turn_external";
}

-------------------------
smacks_hibernation_time = 86400
smacks_max_queue_size = 4000

-- MAM (Message Archive)
mam_enabled = true
mam_archive_default = true
mam_expire_after_days = 30
mam_archive_days = 30
mam_smart_enable = false

-- File upload
http_file_share_size_limit = 32*1024*1024
http_file_share_global_quota = 30*1024*1024*1024
http_file_share_quota = 512*1024*1024
http_file_share_expires_after = "30 days"

-- ======================
-- VIRTUAL HOST
-- ======================

VirtualHost "envs.net"
	authentication = "cyrus"
	cyrus_service_name = "xmpp"
	cyrus_send_tls_cb = true
	allow_registration = false

	modules_enabled = {
		"default_bookmarks";
		"http_altconnect";
		"server_contact_info";
		"server_info";
		"pubsub_serverinfo";
		"pastebin";
	}

	push_keepalive = 60

	http_external_url = "https://envs.net/"
	http_cors_override = {
		["*"] = { "GET"; "POST"; "OPTIONS" }
	}

	pubsub_serverinfo_service = "pubsub.envs.net"
	pubsub_serverinfo_publish_user_count = true

	turn_external_host = "turn.envs.net"
	turn_external_secret = "xxx"
	turn_external_ttl = 86400

	pastebin_threshold = 1500
	pastebin_line_threshold = 10
	pastebin_expire_after = 720
	pastebin_html_preview = true
	pastebin_trigger = "!paste"
	pastebin_ignore = "!nopaste"

	disco_items = {
		{ "conference.envs.net", "Public Channels" };
		{ "pubsub.envs.net", "PubSub Service" };
	}

	default_bookmarks = {
		{ jid = "envs@conference.envs.net"; name = "envs"; autojoin = true };
		{ jid = "lounge@conference.envs.net"; name = "lounge"; autojoin = true };
	}

	contact_info = {
		abuse = { "mailto:hostmaster@envs.net" };
		admin = { "mailto:hostmaster@envs.net", "xmpp:creme@envs.net" };
		security = { "mailto:security@envs.net" };
	}

-- ======================
-- MULTI-USER CHAT (MUC)
-- ======================

Component "conference.envs.net" "muc"
	name = "Rooms"
	restrict_room_creation = "local"

	modules_enabled = {
		"muc_mam";
		"muc_moderation";
		"muc_notifications";
		"pastebin";
	}

	muc_room_locking = true
	muc_tombstones = true

	muc_default_room_options = {
		persistent = true;
		public = true;
		members_only = false;
		moderated = false;
	}

	pastebin_threshold = 1500
	pastebin_line_threshold = 10
	pastebin_expire_after = 720
	pastebin_html_preview = true
	pastebin_trigger = "!paste"
	pastebin_ignore = "!nopaste"

-- ======================
-- HTTP FILE UPLOAD COMPONENT
-- ======================

Component "upload.envs.net" "http_file_share"
	modules_disabled = { "s2s"; }
	http_external_url = "https://upload.envs.net"
	http_file_share_cors = true
	http_cors_override = {
		["*"] = { "GET"; "POST"; "OPTIONS" }
	}

-- ======================
-- PUBSUB COMPONENT
-- ======================

Component "pubsub.envs.net" "pubsub"
	admins = { "envs.net" }
	pubsub_max_items = 1000

-- ======================
-- SOCKS5 BYTESTREAMS PROXY (XEP-0065)
-- ======================

Component "xmppproxy.envs.net" "proxy65"
	proxy65_address = "envs.net"
	modules_disabled = { "s2s"; }

-------------------------

reload_modules = { "tls" }
