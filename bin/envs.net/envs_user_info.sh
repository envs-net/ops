#!/usr/bin/env bash
#
# envs.net - generate users_info.json and user_updates.php
# called by /etc/cron.d/envs_user_info
#
set -euo pipefail

WWW_PATH='/var/www/envs.net'
DOMAIN='envs.net'

if (( EUID != 0 )); then
  printf 'Please run as root!\n' >&2
  exit 1
fi

exec python3 - "$WWW_PATH" "$DOMAIN" <<'PY'
from __future__ import annotations

import grp
import html
import json
import os
import pwd
import re
import sys
import tempfile
from collections import OrderedDict
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

www_path = Path(sys.argv[1])
domain = sys.argv[2]
home_root = Path('/home')


def strip_outer_quotes(value: str) -> str:
    # Match the old helper: strip at most one leading and one trailing quote.
    if value.startswith('"'):
        value = value[1:]
    if value.endswith('"'):
        value = value[:-1]
    return value


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, 0o644)
        try:
            uid = pwd.getpwnam('services').pw_uid
            gid = grp.getgrnam('envs').gr_gid
            os.chown(tmp_name, uid, gid)
        except (KeyError, PermissionError):
            # The production host has these identities. Keeping this fallback
            # makes local/test execution possible without changing the output.
            pass
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def read_envs(info_file: Path):
    desc = ''
    ssh_pubkey = ''
    custom: OrderedDict[str, list[str]] = OrderedDict()

    try:
        lines = info_file.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        return desc, ssh_pubkey, custom

    for line in lines:
        if not line or line.startswith('#') or '=' not in line:
            continue

        # Keep compatibility with the old Bash expansion:
        # field = before first '=', value = after last '='.
        field = line.split('=', 1)[0]
        value = strip_outer_quotes(line.rsplit('=', 1)[1])

        if field == 'desc':
            desc = value
            continue
        if field == 'ssh_pubkey':
            ssh_pubkey = value
            continue

        if field not in custom:
            if len(custom) >= 10:
                continue
            custom[field] = []

        # Old script allows the first value plus up to 31 repeats.
        if len(custom[field]) < 32:
            custom[field].append(value)

    return desc, ssh_pubkey, custom


def has_blog(blog_dir: Path) -> bool:
    try:
        # Old check was: find DIR -maxdepth 1 | wc -l >= 3
        # (the directory itself + at least two entries).
        with os.scandir(blog_dir) as entries:
            seen = 0
            for _ in entries:
                seen += 1
                if seen >= 2:
                    return True
    except OSError:
        pass
    return False


def read_authorized_keys(path: Path) -> list[str]:
    try:
        with path.open('r', encoding='utf-8', errors='replace') as handle:
            return [line.rstrip('\n') for line in handle if line.startswith('ssh')]
    except OSError:
        return []


users: OrderedDict[str, dict] = OrderedDict()
updates: list[tuple[int, str, str]] = []

try:
    user_homes = sorted((p for p in home_root.iterdir() if p.is_dir()), key=lambda p: p.name)
except OSError:
    user_homes = []

for user_home in user_homes:
    username = user_home.name
    info_file = user_home / '.envs'

    desc = ''
    ssh_pubkey = ''
    custom: OrderedDict[str, list[str]] = OrderedDict()
    if info_file.is_file():
        desc, ssh_pubkey, custom = read_envs(info_file)

    if not desc or desc == 'a short describtion or message':
        desc = ''

    public_html = user_home / 'public_html'
    public_gopher = user_home / 'public_gopher'
    public_gemini = user_home / 'public_gemini'

    entry: OrderedDict[str, object] = OrderedDict()
    entry['home'] = str(user_home)
    entry['email'] = f'{username}@{domain}'
    entry['desc'] = desc
    entry['website'] = (
        f'https://{username}.{domain}/'
        if (public_html / 'index.php').is_file() or (public_html / 'index.html').is_file()
        else ''
    )

    if (public_gopher / 'gophermap').is_file():
        entry['gopher'] = f'gopher://{domain}/1/~{username}/'
        entry['gopherproxy'] = f'https://gopher.{domain}/{domain}/1/~{username}/'
    else:
        entry['gopher'] = ''
        entry['gopherproxy'] = ''

    if (public_gemini / 'index.gmi').is_file():
        entry['gemini'] = f'gemini://{domain}/~{username}/'
        entry['geminiproxy'] = f'https://gemini.{domain}/~{username}/'
    else:
        entry['gemini'] = ''
        entry['geminiproxy'] = ''

    entry['blog'] = f'https://{domain}/~{username}/blog/' if has_blog(public_html / 'blog') else ''
    entry['twtxt'] = (
        f'https://{domain}/~{username}/twtxt.txt'
        if (public_html / 'twtxt.txt').is_file()
        else ''
    )

    for field, values in custom.items():
        if not values:
            continue
        entry[field] = values[0] if len(values) == 1 else values

    if re.search(r'[yY1]', ssh_pubkey):
        entry['ssh-pubkey'] = read_authorized_keys(user_home / '.ssh' / 'authorized_keys')

    users[username] = entry

    # Collect the same direct public_html entries used by the old
    # `stat /home/*/public_html/*` pipeline, using ctime like stat %Z.
    try:
        with os.scandir(public_html) as dir_entries:
            for dir_entry in dir_entries:
                full_path = dir_entry.path
                if ('updated' in full_path or
                        'your_index_template.php' in full_path or
                        'cgi-bin' in full_path):
                    continue
                try:
                    st = dir_entry.stat(follow_symlinks=False)
                except OSError:
                    continue
                updates.append((int(st.st_ctime), username, dir_entry.name))
    except OSError:
        pass


data = OrderedDict([
    ('timestamp', str(int(datetime.now().timestamp()))),
    ('data', OrderedDict([
        ('info', OrderedDict([
            ('name', 'envs'),
            ('description', 'envs.net is a minimalist, non-commercial shared linux system and will always be free to use.'),
            ('located', 'germany'),
            ('maintainer', 'Sven Kinne (~creme) - creme@envs.net'),
            ('website', f'https://{domain}/'),
            ('signup_url', f'https://{domain}/signup/'),
            ('gopher', f'gopher://{domain}/'),
            ('gemini', f'gemini://{domain}/'),
            ('email', f'hostmaster@{domain}'),
            ('admin_email', f'sudoers@{domain}'),
            ('user_count', len(user_homes)),
            ('want_users', True),
        ])),
        ('users', users),
    ])),
])

json_text = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
atomic_write(www_path / 'users_info.json', json_text)

# Reverse order by integer ctime and then path, matching `sort -r` closely.
updates.sort(key=lambda row: (row[0], f'/home/{row[1]}/public_html/{row[2]}'), reverse=True)

php: list[str] = [f'''<?php
// do not touch
// this file is generated by /usr/local/bin/envs.net/envs_user_info.sh

    $title = "envs.net | recent user updates";
    $desc = "envs.net | recent user updates";

include 'neoenvs_header.php';
?>

<body id="body">

<!-- Back button -->
<nav class="sidenav">
    <a href="/">
        <img src="https://envs.net/img/envs_logo_200x200.png" class="site-icon" title="Back to the envs.net homepage">
    </a>
</nav>

<!-- main panel -->
<main>

    <div class="block">
        <h1>recent user updates</h1>
    </div>

    <p>this is a static list of the pages modified in <code>/home/*/public_html/*</code>. it updates every hour.</p>

    <ul>
''']

for stamp, username, filename in updates:
    date = datetime.fromtimestamp(stamp).strftime('%F %H:%M:%S')
    user_text = html.escape(f'~{username}')
    file_text = html.escape(filename)
    user_url = f'https://{username}.{domain}/'
    file_url = f'https://{username}.{domain}/{quote(filename)}'
    php.append(
        f'<li><a href="{html.escape(user_url, quote=True)}">{user_text}</a> '
        f'(<a href="{html.escape(file_url, quote=True)}">{file_text}</a>) at {date}</li>\n'
    )

php.append('''    </ul>

</main>

<?php include 'neoenvs_footer.php'; ?>''')

atomic_write(www_path / 'user_updates.php', ''.join(php))
PY
