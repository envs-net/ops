#!/usr/bin/env bash
#
# envs.net - generate sysinfo.json and sysinfo.php
# - this script is called by /etc/cron.d/envs_sysinfo
#
DOMAIN='envs.net'
WWW_PATH='/var/www/envs.net'
JSON_FILE="$WWW_PATH/sysinfo.json"
TMP_JSON='/tmp/sysinfo.json_tmp'

if (( EUID != 0 )); then
  printf 'Please run as root!\n' >&2
  exit 1
fi

SYSINFO_KEYS=(os uptime uname board cpuinfo cpucount)
# Keep external lookups bounded. One unavailable service should not make the
# whole daily job wait indefinitely.
CURL_OPTS=(-fsS --connect-timeout 3 --max-time 8)
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1)

###

# define packages by category for sysinfo.php Page
services=(bbj cryptpad dns drone getwtxt gitea gophernicus hedgedoc ipinfo ntfy
    jetforce mariadb-server nginx openssh-server pleroma privatebin prosody searxng libretranslate thelounge znc)
readarray -t sorted_services < <(printf '%s\n' "${services[@]}" | sort)


shells=(bash csh dash elvish fish ksh mksh sash tcsh xonsh zsh)
readarray -t sorted_shells < <(printf '%s\n' "${shells[@]}" | sort)


editors=(ed emacs micro nano neovim vim)
readarray -t sorted_editors < <(printf '%s\n' "${editors[@]}" | sort)


inet_clients=(alpine av98 bombadillo curl gomuks irssi lynx neomutt meli mutt mosh openssh-client toot w3m weechat wget vf1)
readarray -t sorted_inet_clients < <(printf '%s\n' "${inet_clients[@]}" | sort)


coding_pkg=(cargo clang clisp clojure crystal default-jdk default-jre elixir erlang flex
    g++ gcc gcl gdc ghc go golang guile-2.2 lua5.1 lua5.4 luarocks mono-complete nasm nodejs
    octave perl php picolisp python3 racket ruby rustc scala tcl yasm vlang ziglang)
readarray -t sorted_coding_pkg < <(printf '%s\n' "${coding_pkg[@]}" | sort)


coding_tools=(ack bison build-essential cl-launch cvs devscripts ecl gawk git gron jq latex-mk latexmk
    ninja-build make mawk mercurial rake ripgrep sbcl shellcheck subversion tcc texlive-full virtualenv yarn)
readarray -t sorted_coding_tools < <(printf '%s\n' "${coding_tools[@]}" | sort)


misc=(aria2 bc busybox burrow byobu clinte dict goaccess hugo jekyll linac mariadb-client mandoc mathomatic mkdocs
    pandoc pb pelican screen sqlite3 tmux todotxt-cli twtxt txtnish zola)
readarray -t sorted_misc < <(printf '%s\n' "${misc[@]}" | sort)

# do not add services here!
service_pkgs=(mariadb-server nginx openssh-server)
FULL_PKG_LIST=("${service_pkgs[@]}" "${shells[@]}" "${editors[@]}" "${inet_clients[@]}" "${coding_pkg[@]}" "${coding_tools[@]}" "${misc[@]}")


declare -A PKG_DESC_CACHE=()
declare -A DPKG_VERSION=()

auto_pkg_desc() {
  local pkg="$1"
  printf '%s' "${PKG_DESC_CACHE[$pkg]-}"
}

get_pkg_desc() {
  local pkg="$1"
  [ -z "${pkg_desc:-}" ] && pkg_desc="$(auto_pkg_desc "$pkg")"
  # Rare fallback for virtual/renamed packages not returned by apt-cache show.
  [ -z "$pkg_desc" ] && pkg_desc="$(apt-cache search ^"$pkg"$ 2>/dev/null | awk 'NR==1 {print substr($0, index($0,$3))}')"
  [ -z "$pkg_desc" ] && pkg_desc='n.a.'
}

custom_pkg_desc() {
  local pkg="$1"
  case "$pkg" in
    # system packages (overwrite_pkgs)
    crystal)     pkg_desc='Compiler for the Crystal language';;
    # custom packages
    av98)        pkg_desc='Command line gemini client. High speed, low drag';;
    bombadillo)  pkg_desc='Bombadillo is a non-web browser for the terminal';;
    burrow)      pkg_desc='a helper for building and managing a gopher hole';;
    clinte)      pkg_desc='a community notices system';;
    go)          pkg_desc='tool for managing Go source code';;
    goaccess)    pkg_desc='fast web log analyzer and interactive viewer';;
    linac)       pkg_desc='LINAC is not a compiler';;
    pb)          pkg_desc='a helper utility for using 0x0 pastebin services';;
    python3.13)  pkg_desc="$(get_pkg_desc python3)";;
    twtxt)       pkg_desc='Decentralised, minimalist microblogging service for hackers';;
    txtnish)     pkg_desc='A twtxt client with minimal dependencies';;
    vf1)         pkg_desc='Command line gopher client. High speed, low drag.';;
    vlang)       pkg_desc='Simple, fast, safe, compiled programming language';;
    ziglang)     pkg_desc='general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software.';;
    zola)        pkg_desc='single-binary static site generator written in rust';;

    *) _no_custom_pkg='1' ;;
  esac
}

# Load package descriptions once instead of spawning apt-cache for every table row.
APT_PKGS=()
for pkg in "${FULL_PKG_LIST[@]}"; do
  pkg_desc=''
  _no_custom_pkg='0'
  custom_pkg_desc "$pkg"
  [ -z "$pkg_desc" ] && APT_PKGS+=("$pkg")
done

if ((${#APT_PKGS[@]})); then
  while IFS=$'\t' read -r pkg desc; do
    [ -n "$pkg" ] && [ -z "${PKG_DESC_CACHE[$pkg]-}" ] && PKG_DESC_CACHE["$pkg"]="$desc"
  done < <(
    apt-cache show "${APT_PKGS[@]}" 2>/dev/null |
      awk '
        /^Package: / { pkg=$2 }
        /^(Description|Description-en): / && !seen[pkg] {
          line=$0
          sub(/^[^:]+:[[:space:]]*/, "", line)
          print pkg "\t" line
          seen[pkg]=1
        }
      '
  )
fi

# Load all dpkg versions in one process. Missing packages intentionally remain
# empty, matching the old per-package dpkg-query behaviour.
while IFS=$'\t' read -r pkg version; do
  [ -n "$pkg" ] && DPKG_VERSION["$pkg"]="$version"
done < <(dpkg-query -W -f='${Package}\t${Version}\n' "${FULL_PKG_LIST[@]}" 2>/dev/null || true)

# Collect all six values over a single SSH connection per remote host.
declare -A SYS_SRV=() SYS_CORE=() SYS_EXT=()

collect_local_sysinfo() {
  local key
  for key in "${SYSINFO_KEYS[@]}"; do
    SYS_CORE["$key"]="$(/opt/sysinfo.sh get "$key" 2>/dev/null || true)"
  done
}

collect_remote_sysinfo() {
  local host="$1"
  local map_name="$2"
  local key value
  local -n out="$map_name"

  while IFS=$'\t' read -r key value; do
    [ -n "$key" ] && out["$key"]="$value"
  done < <(
    ssh "${SSH_OPTS[@]}" "$host"       'for k in os uptime uname board cpuinfo cpucount; do v=$(/opt/sysinfo.sh get "$k" 2>/dev/null || true); printf "%s\t%s\n" "$k" "$v"; done'       2>/dev/null || true
  )

  for key in "${SYSINFO_KEYS[@]}"; do
    : "${out[$key]:=}"
  done
}

collect_remote_sysinfo "srv.$DOMAIN" SYS_SRV
collect_local_sysinfo
collect_remote_sysinfo "ext.$DOMAIN" SYS_EXT


#
# SYSINFO.JSON
#
print_pkg_version() {
  local pkg
  local pkg_version
  overwrite_pkgs=('crystal')

  for pkg in "${FULL_PKG_LIST[@]}"; do
    pkg_desc=''
    _no_custom_pkg='0'
    custom_pkg_desc "$pkg"
    for o_pkg in "${overwrite_pkgs[@]}"; do
      if [ "$_no_custom_pkg" -eq '1' ] || [ "$pkg" = "$o_pkg" ]; then
        pkg_version="${DPKG_VERSION[$pkg]-}"
        printf '      "%s": "%s",\n' "$pkg" "$pkg_version"
      fi
    done
  done
}


cat<<EOM > "$TMP_JSON"
{
  "timestamp":    "$(date +'%s')",
  "data": {
    "info": {
      "name":         "envs",
      "description":  "envs.net is a minimalist, non-commercial shared linux system and will always be free to use.",
      "located":      "germany",
      "maintainer":   "Sven Kinne (~creme) - creme@envs.net",
      "website":      "https://$DOMAIN/",
      "signup_url":   "https://$DOMAIN/signup/",
      "gopher":       "gopher://$DOMAIN/",
      "gemini":       "gemini://$DOMAIN/",
      "email":        "hostmaster@$DOMAIN",
      "admin_email":  "sudoers@$DOMAIN",
      "user_count":   $(find /home -mindepth 1 -maxdepth 1 -type d | wc -l)
    },
    "SSHFP": {
      "RSA":          "SHA256:7dB470mfzlyhhtqmjnXciIxp+jWLACiYKC3EE/Z0lFg",
      "ECDSA":        "SHA256:U0C6SKGXUflve16m2l4KWBdLLARW6O8TiGWZsXAU2i4",
      "ED25519":      "SHA256:V+mXTsRJ+jfJMxxPlD/28dpWouuns3Wuqwppv6ykVC8"
    },
    "system": {
      "srv.$DOMAIN": {
        "location":     "Hetzner (Helsinki)",
        "os":           "${SYS_SRV[os]}",
        "uptime":       "${SYS_SRV[uptime]}",
        "uname":        "${SYS_SRV[uname]}",
        "board":        "${SYS_SRV[board]}",
        "cpuinfo":      "${SYS_SRV[cpuinfo]}",
        "cpucount":     "${SYS_SRV[cpucount]}"
      },
      "core.$DOMAIN": {
        "location":     "VM on srv.envs.net",
        "os":           "${SYS_CORE[os]}",
        "uptime":       "${SYS_CORE[uptime]}",
        "uname":        "${SYS_CORE[uname]}",
        "board":        "${SYS_CORE[board]}",
        "cpuinfo":      "${SYS_CORE[cpuinfo]}",
        "cpucount":     "${SYS_CORE[cpucount]}"
      },
      "ext.$DOMAIN": {
        "location":     "netcup (Nürnberg)",
        "os":           "${SYS_EXT[os]}",
        "uptime":       "${SYS_EXT[uptime]}",
        "uname":        "${SYS_EXT[uname]}",
        "board":        "${SYS_EXT[board]}",
        "cpuinfo":      "${SYS_EXT[cpuinfo]}",
        "cpucount":     "${SYS_EXT[cpucount]}"
      }
    },
    "services": {
      "bbj": {
        "desc":        "bulletin butter & jelly: an http bulletin board server for small communities",
        "version":     "-",
        "url":         "https://bbj.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "cryptpad": {
        "desc":        "collaborative real time editing",
        "version":     "$(curl "${CURL_OPTS[@]}" https://pad."$DOMAIN"/api/config | awk -F= '/ver=/ {print $2}' | sed '$ s/"$//')",
        "url":         "https://pad.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "dns": {
        "desc":        "public dns resolver supporting doh and dot",
        "version":     "-",
        "url":         "https://dns.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "drone": {
        "desc":        "continuous delivery platform",
        "version":     "$(curl "${CURL_OPTS[@]}" https://drone."$DOMAIN"/version | jq -Mr .version)",
        "url":         "https://drone.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "getwtxt": {
        "desc":        "twtxt registry service - microblogging for hackers",
        "version":     "$(curl "${CURL_OPTS[@]}" https://twtxt."$DOMAIN"/api/plain/version | awk '{print $2}')",
        "url":         "https://twtxt.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "gitea": {
        "desc":        "painless self-hosted git service",
        "version":     "$(curl "${CURL_OPTS[@]}" https://git."$DOMAIN"/api/v1/version | jq -Mr .version)",
        "url":         "https://git.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "gophernicus": {
        "desc":        "modern full-featured (and hopefully) secure gopher daemon",
        "version":     "$(/usr/local/sbin/gophernicus -v | sed 's/Gophernicus\///' | awk '{print $1}')",
        "url":         "gopher://$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "hedgedoc": {
        "desc":        "collaborative real time markdown",
        "version":     "$(curl "${CURL_OPTS[@]}" -I https://hedgedoc."$DOMAIN"/ | awk '/^hedgedoc-version:/{print $2}'| tr -d "\015")",
        "url":         "https://hedgedoc.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "ipinfo": {
        "desc":        "ip address info",
        "version":     "-",
        "url":         "https://ip.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "ntfy": {
        "desc":        "a simple HTTP-based pub-sub notification service",
        "version":     "$(dpkg -s ntfy | awk '/Version:/ {print $2}' | head -n1)",
        "url":         "https://ntfy.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "jetforce": {
        "desc":        "tcp server for the gemini protocol",
        "version":     "$(/srv/jetforce/.local/bin/jetforce -V | awk '{printf $2}')",
        "url":         "https://gemini.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "pleroma": {
        "desc":        "federated social network - microblogging",
        "version":     "$(curl "${CURL_OPTS[@]}" https://pleroma."$DOMAIN"/api/v1/instance | jq -Mr .version | awk '{print $4}' | sed '$ s/)//')",
        "url":         "https://pleroma.$DOMAIN/",
        "server":      "ext.$DOMAIN"
      },
      "privatebin": {
        "desc":        "graphical pastebin",
        "version":     "-",
        "url":         "https://pb.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "prosody": {
        "desc":        "lightweight jabber/xmpp server",
        "version":     "$(dpkg -s prosody | awk '/Version:/ {print $2}' | head -n1)",
        "url":         "https://xmpp.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "searxng": {
        "desc":        "privacy-respecting metasearch engine",
        "version":     "$(curl "${CURL_OPTS[@]}" https://searx."$DOMAIN"/config | jq -Mr .version)",
        "url":         "https://searx.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "libretranslate": {
        "desc":        "free and open source machine translation api",
        "version":     "$(curl "${CURL_OPTS[@]}" https://translate."$DOMAIN"/spec | jq -r '.info.version')",
        "url":         "https://translate.$DOMAIN/",
        "server":      "srv.$DOMAIN"
      },
      "thelounge": {
        "desc":        "self-hosted web irc client",
        "version":     "$(sudo -u thelounge /srv/thelounge/.yarn/bin/thelounge -v | awk -Fv '{print $2}')",
        "url":         "https://webirc.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "znc": {
        "desc":        "advanced modular irc bouncer",
        "version":     "$(dpkg -s znc | awk '/Version:/ {print $2}' | head -n1)",
        "url":         "https://znc.$DOMAIN/",
        "server":      "core.$DOMAIN"
      }
    },
    "packages": {
      "av98":         "$(/usr/local/bin/av98 --version | awk '{print $2}')",
      "bombadillo":   "$(/usr/local/bin/bombadillo -v | awk '/Bombadillo/ {print $2}')",
      "burrow":       "$(/usr/local/bin/burrow -v | awk -Fv '{print $2}')",
      "clinte":       "$(/usr/local/bin/clinte -V | awk '/clinte/ {print $2}')",
      "go":           "$(awk -Fgo '{print $2}' /usr/local/go/VERSION)",
      "goaccess":     "$(/usr/bin/goaccess -V | awk '/GoAccess/ {print $3}')",
      "pb":           "$(/usr/local/bin/pb -v)",
      "twtxt":        "$(/usr/local/bin/twtxt --version | awk '/version/ {printf $3}')",
      "txtnish":      "$(/usr/local/bin/txtnish -V)",
      "vf1":          "$(/usr/local/bin/vf1 --version | awk '/VF-1/ {print $2}')",
      "vlang":        "$(/usr/local/bin/v --version | awk '/V/ {print $2}')",
      "ziglang":      "$(/usr/local/bin/zig version)",
      "zola":         "$(/usr/local/bin/zola -V | awk '/zola/ {print $2}')",
$(print_pkg_version)
EOM
      # remove trailing ',' on last line
      sed -i '$ s/,$//' "$TMP_JSON"

cat<<EOM >> "$TMP_JSON"
    }
  }
}
EOM

mv "$TMP_JSON" "$JSON_FILE"
chown services:envs "$JSON_FILE"

# Parse the generated JSON once. The old script spawned jq repeatedly for every
# package/service while building the HTML table.
declare -A JSON_PKG_VERSION=()
declare -A SERVICE_DESC=() SERVICE_VERSION=() SERVICE_URL=() SERVICE_SERVER=()

while IFS=$'\t' read -r pkg version; do
  JSON_PKG_VERSION["$pkg"]="$version"
done < <(jq -r '.data.packages | to_entries[] | [.key, (.value // "")] | @tsv' "$JSON_FILE")

while IFS=$'\t' read -r service desc version url server; do
  SERVICE_DESC["$service"]="$desc"
  SERVICE_VERSION["$service"]="$version"
  SERVICE_URL["$service"]="$url"
  SERVICE_SERVER["$service"]="$server"
done < <(jq -r '.data.services | to_entries[] | [.key, (.value.desc // ""), (.value.version // ""), (.value.url // ""), (.value.server // "")] | @tsv' "$JSON_FILE")


#
# SYSINFO.PHP
#
print_pkg_info() {
  local pkg="$1"

  local pkg_version="${JSON_PKG_VERSION[$pkg]-}"
  [ -z "$pkg_version" ] && pkg_version='n.a.'

  local pkg_desc=''
  _no_custom_pkg='0'
  custom_pkg_desc "$pkg"
  get_pkg_desc "$pkg"
  # remove description-en string
  pkg_desc="${pkg_desc//Description-en: /}"
  # replace double quotes with single quote
  pkg_desc="${pkg_desc//\"/\'}"
  # string to lowercase
  pkg_desc="${pkg_desc,,}"

  printf '\t\t<tr> <td>%s</td> <td>%s</td> <td>%s</td> </tr>\n' "$pkg" "$pkg_version" "$pkg_desc"
}

print_pkg_info_services() {
  local pkg="$1"
  printf '\t\t<tr> <td><a href="%s" target="_blank">%s</a></td> <td>%s</td> <td>%s</td> </tr>\n' \
    "${SERVICE_URL[$pkg]-}" "$pkg" "${SERVICE_VERSION[$pkg]-}" "${SERVICE_DESC[$pkg]-}"
}

print_category() {
  local category="$1"
  shift
  local arr=("$@")

  if [ "$category" = 'services' ]; then
    printf '<details open=""><summary class="menu" id="%s"><strong>&#35; %s</strong></summary>\n' "$category" "${category//_/ }"
  else
    printf '<details><summary class="menu" id="%s"><strong>&#35; %s</strong></summary>\n' "$category" "${category//_/ }"
  fi

  printf '\t<table class="table-pkg">\n'
  printf '\t\t<tr> <th class="tw16">Package</th> <th class="tw36">Version</th> <th class="tw85">Description</th> </tr>\n'

  if [ "$category" = 'services' ]; then
    for pkg in "${arr[@]}"; do
      if [[ -v SERVICE_DESC[$pkg] ]]; then
        print_pkg_info_services "$pkg"
      else
        print_pkg_info "$pkg"
      fi
    done
  else
    for pkg in "${arr[@]}"; do print_pkg_info "$pkg"; done
  fi

  printf '\t</table>\n</details>\n<p></p>\n'
}

print_srv_services() {
  local srv="${1}.envs.net"
  shift
  local arr=("$@")
  local service

  for service in "${arr[@]}"; do
    if [ "${SERVICE_SERVER[$service]-}" = "$srv" ]; then
      printf '<a href="%s" target="_blank">%s</a> ' "${SERVICE_URL[$service]-}" "$service"
    fi
  done
}


cat<<EOM > /tmp/sysinfo.php_tmp
<?php
// do not touch
// this files is generated by /usr/local/bin/envs.net/envs_sysinfo.sh
  \$title = "$DOMAIN | sysinfo";
  \$desc = "$DOMAIN | sysinfo";

  \$date = new DateTime(null, new DateTimeZone('Etc/UTC'));
  \$datetime = \$date->format('l, d. F Y - h:i:s A (e)');

  \$local_hostname = shell_exec("hostname");
  \$local_os = shell_exec("lsb_release -ds");

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
		<h1>sysinfo</h1>

		<p><em>full data source: <a href="/sysinfo.json">https://$DOMAIN/sysinfo.json</a></em><br>
		<em>status page: <a href="https://status.envs.net/" target="_blank">https://status.envs.net/</a></em></p>

		<p><em>server admin: <a href="/~creme/">&#126;creme</a></em></p>
	</div>

	<div class="block">
		<p><strong><i class="fa fa-gear fa-fw" aria-hidden="true"></i> SYSTEM INFO</strong></p>
		<table>
		  <tr><th class="tw13_75"></th> <th></th></tr>
		  <tr><td>time:</td> <td><?=\$datetime?></td></tr>
		  <tr><td>&nbsp;</td> <td></td></tr>
		  <tr><td><strong>srv.envs.net</strong></td> <td></td></tr>
		  <tr><td>location:</td> <td>Hetzner (Helsinki)</td></tr>
		  <tr><td>os:</td> <td>Debian GNU/Linux 13 (trixie)</td></tr>
		  <tr><td>disk space:</td> <td>2x512TB ssd-nvme | 2x1TB ssd-SATA</td></tr>
		  <tr><td>services:</td> <td>$(print_srv_services 'srv' "${sorted_services[@]}")</td></tr>
		  <tr><td><hr></td> <td><hr></td></tr>
		  <tr><td><strong><?=\$local_hostname?></strong></td> <td></td></tr>
		  <tr><td>location:</td> <td>VM on srv.envs.net</td></tr>
		  <tr><td>os:</td> <td><?=\$local_os?></td></tr>
		  <tr><td>disk space:</td> <td>150GB ssd-nvme <small>(/)</small> | 500GB ssd-SATA <small>(/var /home)</small></td></tr>
		  <tr><td>services:</td> <td>tilde shell $(print_srv_services 'core' "${sorted_services[@]}")</td></tr>
		  <tr><td><hr></td> <td><hr></td></tr>
		  <tr><td><strong>ext.envs.net</strong></td> <td></td></tr>
		  <tr><td>location:</td> <td>netcup (Nürnberg)</td></tr>
		  <tr><td>os:</td> <td>Debian GNU/Linux 13 (trixie)</td></tr>
		  <tr><td>disk space:</td> <td>512GB ssd-nvme</td></tr>
		  <tr><td>services:</td> <td>secondary DNS and mail server, $(print_srv_services 'ext' "${sorted_services[@]}")</td></tr>
		</table>
	</div>

	<p>this is a static list of the package informations. it updates once per day.</p>

	<p><strong>&#35; can i get [package] installed?</strong><br>
	probably! send an email with your suggestion to <a href="mailto:sudoers@$DOMAIN">sudoers@$DOMAIN</a>.</p>


$(print_category 'services' "${sorted_services[@]}")
$(print_category 'shells' "${sorted_shells[@]}")
$(print_category 'editors' "${sorted_editors[@]}")
$(print_category 'online_browser_and_clients' "${sorted_inet_clients[@]}")
$(print_category 'coding_packages' "${sorted_coding_pkg[@]}")
$(print_category 'coding_tools' "${sorted_coding_tools[@]}")
$(print_category 'misc' "${sorted_misc[@]}")

</main>

<?php include 'neoenvs_footer.php'; ?>

EOM

mv /tmp/sysinfo.php_tmp "$WWW_PATH"/sysinfo.php
chown services:envs "$WWW_PATH"/sysinfo.php

#
exit 0
