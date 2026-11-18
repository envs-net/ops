# envs-web(7) – Administratorhandbuch

**Stand:** 1. November 2026 · **System:** core.envs.net (Debian 13)  
**Werkzeuge:** `envs_php_fpm_manage` **v20.4.2**, `envs_web_autoprovision` **v1.2.2**

## NAME

`envs-web` – PHP-FPM-/CGI-Isolation, manuelle Verwaltung und automatische Provisionierung.

## BESCHREIBUNG

Statische HTML-Dateien liefert nginx direkt aus. Für Shell-Benutzer werden bei Bedarf isolierte PHP-FPM- und CGI-Dienste mit ihrer jeweiligen UID eingerichtet. Die Standard-Webrouten sind `username.envs.net`, `envs.net/~username` und `envs.net/u/username`. Ohne eigene PHP-/CGI-Backend-Route antworten die geschützten Standard-Webrouten mit **HTTP 403** statt mit dem gemeinsamen `www-data`-Fallback. Individuelle Custom-VHosts sind separat zu prüfen.

Der Auto-Provisioner überprüft alle relevanten Benutzerkonten, provisioniert fehlende Dienste und schreibt neue nginx-Routen gesammelt. Er verändert keine Benutzerdateien mittels `chmod`/`chown`. Der manuelle Manager bietet zusätzliche Diagnose- und Wartungsbefehle. Historische DRAFT-Header können weiterhin in Offline-Review-Vorlagen vorkommen; **produktive** Pool-Konfigurationen und PHP-systemd-Templates sind auf v20.4.2 bereinigt.

---

## ENVS_WEB_AUTOPROVISION(8) – Version 1.2.2

### AUFRUF

```bash
envs_web_autoprovision [--user USER] [--max-accounts N]
envs_web_autoprovision --apply [--user USER] [--max-accounts N]
envs_web_autoprovision --help
```

### OPTIONEN

| Option | Bedeutung |
|---|---|
| ohne `--apply` | **Vorschau**, keine Änderungen; scannt und prüft Backend-Routen; JSONL auf stdout. |
| `--apply` | Führt erforderliche Einrichtung und Routingänderungen aus; vorhandene Routen werden geprüft. |
| `--user USER` | Betrachtet nur ein angegebenes Shell-Konto. |
| `--max-accounts N` | Ändert höchstens N Konten pro Lauf (1–50, Standard 10); **begrenzt nicht den globalen Scan**. |
| `--manager PFAD` | Lädt einen alternativen Manager; nur für gezielt geprüfte Admin-/Entwicklungsfälle. |
| `--help` | Zeigt die Kommandozeilenhilfe an. |

### BEISPIELE

```bash
# Gesamten Bestand rein lesend prüfen
envs_web_autoprovision

# Nur eine einzelne Site prüfen
envs_web_autoprovision --user creme

# Einen Benutzer produktiv abgleichen; kann nginx neu laden!
envs_web_autoprovision --apply --user USER --max-accounts 1

# Von systemd verwendeter Produktionsmodus
envs_web_autoprovision --apply --max-accounts 10
```

### AUSGABE UND EXITSTATUS

stdout enthält **JSONL** (ein JSON-Objekt pro Zeile), etwa `scan`, `plan`, `staged`, `nginx_batch_transaction`, `nginx_batch_reloaded`, `activated`, `deferred`, `skip`, `blocked`, `drift`, `complete` oder `fatal`. Textausgaben des Managers und Fehler gehen an stderr.

| Feld | Bedeutung |
|---|---|
| `complete.changed_accounts` | Geänderte Konten im Lauf. |
| `complete.deferred` | Wegen Batch-Limit verschobene Aktionen. |
| `complete.blocked` | Blockierte Fälle. |
| `complete.errors` | Ausführungsfehler. |
| `complete.skipped` | Bewusst übersprungene Fälle. |
| `complete.drift` | Abweichung vorhandener, verwalteter Dienste/Routen. |
| `fail_closed_verified` | Schutzregeln für nginx geprüft. |

Exitcodes: **0** = kein Ausführungsfehler/Drift (einzelne Warnungen sind möglich); **1** = Fehler oder Drift; **2** = fataler Zustand/Voraussetzung.

### TRANSAKTIONEN

- Temporäre Dateien: `/var/lib/envs-web-autoprovision/transactions/nginx-batch-*`
- Nach erfolgreicher Veröffentlichung oder geprüftem Rollback: automatisch entfernt.
- Bei fehlgeschlagenem Rollback: Transaktion bleibt erhalten, plus persistente Sperrmarkierung `/var/lib/envs-web-autoprovision/nginx-pending`.
- Die ältere `/run/envs-web-autoprovision-nginx-pending` wird weiterhin geprüft.
- **Eine vorhandene Pending-Markierung nie blind löschen oder durch wiederholtes `--apply` umgehen.** Zuerst Maps, Sicherung und Journal prüfen.

---

## ENVS_PHP_FPM_MANAGE(8) – Version 20.4.2

### AUFRUF

```bash
envs_php_fpm_manage AKTION [BENUTZER] [OPTIONEN]
envs_php_fpm_manage AKTION --help
envs_php_fpm_manage --help
```

### LESENDE AKTIONEN

| Aktion | Beschreibung |
|---|---|
| `plan USER` | PHP-Isolationsmodell, UID, Webroot und Voraussetzungen. |
| `status USER` | PHP-FPM-Konfiguration, Backend-Route und systemd-Bootstatus. |
| `check USER` | Verwaltete PHP-Pooldatei und Aktivierungsmarker prüfen. |
| `discover [--user USER] [--summary] [--with-cgi]` | Rekursive PHP-Bestandsaufnahme; optional CGI-Klassifikation ergänzen. |
| `sync --dry-run [--user USER]` | Read-only-Kandidatenliste; `--dry-run` ist erforderlich. |
| `cgi-inventory [--user USER] [--summary] [--json]` | CGI-Inventur; bei `--json` maschinenlesbar (Schema v2). Scan-/Sicherheitsbefunde können zu Exitcode 1 führen. |
| `cgi-plan USER` | CGI-Dateien, geplante Units/Sockets und Reihenfolge. |
| `cgi-status USER` | CGI-Konfiguration, Workerzahl, Bootstatus und nginx-Route. |
| `cgi-audit USER` | Orientierende CGI-Prüfung; fehlende private Route nicht immer Fehler. |
| `cgi-check USER` | Strenge CGI-Prüfung; fehlende Route ist ein Fehler. |
| `cgi-idle-status USER` | Socket-/Servicezustand; **kein** zuverlässiger In-Flight-/Idle-Zähler, kein Auto-Idle-Stop. |

### OFFLINE-REVIEW

`stage USER --review-only` erzeugt nur private Reviewdateien (unter Umständen in `/root`). Keine Produktivänderung oder Dienstaktivierung. `--review-only` ist Pflicht.

### AKTIONEN MIT OPTIONALEN SCHREIBZUGRIFFEN

Alle nachfolgenden Aktionen laufen standardmäßig als **Vorschau**. Erst `--commit` führt Änderungen aus; `--dry-run` erzwingt die Vorschau.

| Aktion | Beschreibung |
|---|---|
| `add USER` | Private PHP-FPM-Pool-/Unit-Konfiguration erstellen, zunächst ohne Aktivierung/Route. |
| `enable USER` | PHP-Aktivierungsmarker und Socket aktivieren; noch kein nginx-Routing. |
| `route USER` | nginx-PHP-Route zum privaten Socket veröffentlichen. |
| `unroute USER` | Private PHP-Route entfernen; **danach HTTP 403** an der geschützten Standardroute. |
| `disable USER` | Private PHP-Dienste abschalten, wenn Routing und alte Worker dies zulassen. |
| `remove USER` | Private PHP-Dateien nach `unroute`/`disable` entfernen. |
| `cgi-stage USER` | Private CGI-systemd-Units schreiben; nicht starten/routen. |
| `cgi-enable USER` | Privaten CGI-Socket aktivieren. |
| `cgi-route USER` | Private CGI-Route veröffentlichen. |
| `cgi-unroute USER` | Private CGI-Route entfernen; Standard-Fallback bleibt mit 403 gesperrt. |
| `cgi-disable USER` | Private CGI-Units abschalten, wenn keine Route darauf zeigt. |
| `cgi-remove USER` | CGI-Unit-Dateien nach Abschaltung entfernen. |
| `cgi-workers USER --workers {1,2,3,4}` | CGI-Workerzahl ändern; **kein automatischer Dienstneustart**. |

### OPTIONEN FÜR ÄNDERUNGEN

| Option | Bedeutung |
|---|---|
| `--dry-run` | Vorschau erzwingen. |
| `--commit` | Produktive Änderungen durchführen; nicht für reine Audits verwenden. |
| `--confirm-uid UID` | Aktuelle Benutzer-UID explizit bestätigen. |
| `--confirm-reviewed` | Manuelle Vorprüfung bestätigen (PHP `enable`/`route`, CGI `cgi-enable`/`cgi-route`). |
| `--confirm-legacy-fallback` | Nur bei `cgi-unroute`; ändert nicht die nginx-Fail-Closed-Guards. |

### BEISPIELE (SICHER LESEND)

```bash
envs_php_fpm_manage status creme
envs_php_fpm_manage check piuvas
envs_php_fpm_manage cgi-status creme
envs_php_fpm_manage cgi-check winter
envs_php_fpm_manage discover --summary --with-cgi
envs_php_fpm_manage cgi-inventory --summary
envs_php_fpm_manage cgi-inventory --user creme
envs_php_fpm_manage cgi-inventory --json > /var/tmp/envs-cgi.json
envs_php_fpm_manage cgi-idle-status creme
envs_php_fpm_manage route piuvas --dry-run
envs_php_fpm_manage cgi-workers creme --workers 2 --dry-run
```

**Hinweis:** Bei manuellen Routing-Aktionen erstellt der Manager weiterhin historische Sicherungen unter `/root` (`envs-php-v20-map-*`, `envs-cgi-v20-2-map-*`). Der **automatische** Provisioner verwendet dagegen sein eigenes, temporäres Transaktionssystem.

---

## SYSTEMD UND REGELBETRIEB

Timer `envs-web-autoprovision.timer` → Service `envs-web-autoprovision.service`, `OnCalendar=*:0/15`, produktiver Override `--apply --max-accounts 10`.

```bash
# Timerstatus und nächsten Lauf anzeigen
systemctl status envs-web-autoprovision.timer --no-pager
systemctl list-timers --all envs-web-autoprovision.timer

# Letzten Lauf prüfen
systemctl status envs-web-autoprovision.service --no-pager
journalctl -u envs-web-autoprovision.service -n 100 --no-pager

# Für Wartung anhalten / nach Wartung starten
systemctl stop envs-web-autoprovision.timer
systemctl start envs-web-autoprovision.timer

# Syntax und Ressourcen prüfen (kein nginx-Reload)
nginx -t
systemctl show nginx.service -p MainPID -p TasksCurrent -p MemoryCurrent
```

**Achtung:** Ein bereits laufender Oneshot-Service wird nicht automatisch durch das Stoppen des Timers beendet. Mit `Persistent=true` kann beim erneuten Start ein Nachhollauf entstehen.

## DATEIEN UND PFADE

| Pfad | Funktion |
|---|---|
| `/home/USER/public_html/` | Benutzer-Webroot (HTML, PHP, CGI). |
| `/etc/envs/php-fpm/user-USER.conf`, `user-USER.allow` | Root-verwalteter PHP-Pool und Aktivierungsmarker. |
| `/etc/nginx/sites-enabled/user.envs.net.conf` | PHP-Backend-Map. |
| `/etc/nginx/conf.d/envs-cgi-backends.conf` | CGI-Backend-Map. |
| `/etc/nginx/snippets/user.envs.conf` | Subdomain-Fail-Closed-Guards. |
| `/etc/nginx/snippets/envs_user_alias_php` | PHP-Fail-Closed der Alias-Routen. |
| `/etc/nginx/sites-enabled/envs.net.conf` | CGI-Fail-Closed für `/~user` und `/u/user`. |
| `/run/envs-php-user-USER/php.sock` | Privater PHP-FPM-Socket. |
| `/run/envs-cgi-user-USER/fcgiwrap.sock` | Privater CGI-Socket. |
| `/etc/systemd/system/envs-php-user@.service` und `.socket` | PHP-FPM-systemd-Templates. |
| `/etc/systemd/system/envs-cgi-user-USER.service` und `.socket` | Private CGI-systemd-Units. |
| `/var/lib/envs-web-autoprovision/transactions/` | Kurzlebige Transaktionen, normalerweise leer. |
| `/var/lib/envs-web-autoprovision/nginx-pending` | Persistente Sperre bei offenem Deployment. |
| `/var/backups/envs-web-autoprovision/` | Installer-/Versionsbackups. |
| `/var/backups/envs-php-fpm-cosmetic/` | Backup der kosmetischen Manager-Umstellung auf v20.4.2. |

## ROOT-CLEANUP(8) – Optionales Aufräumskript

```bash
bash envs-root-cleanup.sh --list    # Vorschau, Standard
bash envs-root-cleanup.sh --apply   # Ausgewählte historische Dateien archivieren
```

Das Hilfsskript verschiebt nur explizit gelistete Migrationsquellen, Logs und Testartefakte nach `/root/archive/envs-web-hardening/root-cleanup-*/` und schreibt ein `MANIFEST.tsv` mit Original-/Zielpfad. **Es löscht nichts**, ändert keine Produktivdienste und lässt Rollback-Sicherungen, Quotas, Dotfiles, Zugangsdaten, Backups, Benutzerdateien und persönliche Ordner unangetastet. Die Liste vor `--apply` sorgfältig prüfen. Es gehört **nicht** zum automatischen Provisioner.

## FEHLERSUCHE

- Ein neues PHP-/CGI-Skript kann bis zum nächsten Provisionierungslauf HTTP 403 erhalten; statisches HTML ist davon unabhängig.
- `scan` und `complete` ohne `plan`/`staged` bedeuten normalerweise: nichts zu ändern.
- Eine erfolgreiche Vorschau ist noch kein End-to-End-Test eines neu eingerichteten Benutzers.
- Bei echter Routingänderung kann nginx einmal pro Batch neu geladen werden; bei Rollback ggf. ein weiteres Mal. Lang laufende WebSockets können alte Worker halten (`worker_shutdown_timeout 1h`).
- Custom-VHosts, Spezialrouten und Benutzerrechte müssen separat geprüft werden.
- Die Fail-Closed-Guards **nicht** entfernen, um HTTP 403 zu umgehen.
- Eine offene `nginx-pending`-Markierung nur nach technischer Prüfung bearbeiten.

## SIEHE AUCH

`envs_web_autoprovision --help`, `envs_php_fpm_manage --help`, `envs_php_fpm_manage AKTION --help`, `systemctl(1)`, `systemd.timer(5)`, `journalctl(1)`, `nginx(8)`.
