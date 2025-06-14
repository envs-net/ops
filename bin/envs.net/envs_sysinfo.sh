#!/usr/bin/env bash
#
# envs.net - generate sysinfo.json and sysinfo.php
# - this script is called by /etc/cron.d/envs_sysinfo
#
DOMAIN='envs.net'
WWW_PATH='/var/www/envs.net'
JSON_FILE="$WWW_PATH/sysinfo.json"
TMP_JSON='/tmp/sysinfo.json_tmp'

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

###

# define packages by category for sysinfo.php Page
services=(0x0 bbj cinny cryptpad drone element-web getwtxt gitea gophernicus hedgedoc hydrogen-web ipinfo
    jetforce mariadb-server matrix nginx ntfy openssh-server pleroma privatebin searxng tt-rss thelounge znc)
readarray -t sorted_services < <(printf '%s\n' "${services[@]}" | sort)


shells=(bash csh dash elvish fish ksh mksh sash tcsh xonsh yash zsh)
readarray -t sorted_shells < <(printf '%s\n' "${shells[@]}" | sort)


editors=(ed emacs micro nano neovim vim)
readarray -t sorted_editors < <(printf '%s\n' "${editors[@]}" | sort)


inet_clients=(alpine av98 bombadillo curl gomuks irssi lynx neomutt meli mutt mosh openssh-client toot w3m weechat wget vf1)
readarray -t sorted_inet_clients < <(printf '%s\n' "${inet_clients[@]}" | sort)


coding_pkg=(cargo clang clisp clojure crystal default-jdk default-jre dmd-compiler elixir erlang flex
    g++ gcc gcl gdc gforth ghc go golang guile-2.2 inform julia lua5.1 lua5.2 lua5.3 mono-complete nasm nim nodejs
    octave perl php picolisp ponyc python python2.7 python3 python3.13 racket ruby rustc scala tcl yasm vlang ziglang)
readarray -t sorted_coding_pkg < <(printf '%s\n' "${coding_pkg[@]}" | sort)


coding_tools=(ack bison build-essential cl-launch cvs devscripts ecl gawk git gron initscripts jq latex-mk latexmk
    ninja-build make mawk mercurial rake ripgrep sbcl shellcheck subversion tcc texlive-full virtualenv yarn)
readarray -t sorted_coding_tools < <(printf '%s\n' "${coding_tools[@]}" | sort)


misc=(aria2 bc busybox burrow byobu clinte dict gfu goaccess hugo jekyll linac mariadb-client mandoc mathomatic mathtex mkdocs
    pandoc pb pelican sagemath screen sqlite3 tmux todotxt-cli twtxt txtnish zola)
readarray -t sorted_misc < <(printf '%s\n' "${misc[@]}" | sort)

# do not add services here!
service_pkgs=(mariadb-server nginx openssh-server)
FULL_PKG_LIST=("${service_pkgs[@]}" "${shells[@]}" "${editors[@]}" "${inet_clients[@]}" "${coding_pkg[@]}" "${coding_tools[@]}" "${misc[@]}")


get_pkg_desc() {
  local pkg="$1"
  [ -z "$pkg_desc" ] && pkg_desc="$(apt-cache show "$pkg" | awk '/Description-en/ {print substr($0, index($0,$2))}' | head -1)"
  [ -z "$pkg_desc" ] && pkg_desc="$(apt-cache search ^"$pkg"$ | awk '{print substr($0, index($0,$3))}' | head -1)"
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
    gfu)         pkg_desc='A utility for formatting gophermaps';;
    go)          pkg_desc='tool for managing Go source code';;
    goaccess)    pkg_desc='fast web log analyzer and interactive viewer';;
    linac)       pkg_desc='LINAC is not a compiler';;
    micro)       pkg_desc='a new modern terminal-based text editor';;
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


#
# SYSINFO.JSON
#
print_pkg_version() {
  local pkg_version
  overwrite_pkgs=('crystal')

  #for pkg in $(dpkg-query -f '${binary:Package}\n' -W); do
  for pkg in "${FULL_PKG_LIST[@]}"; do
    _no_custom_pkg='0' ; custom_pkg_desc "$pkg"
    for o_pkg in "${overwrite_pkgs[@]}"; do
      if [ "$_no_custom_pkg" -eq '1' ] || [ "$pkg" = "$o_pkg" ]; then
        pkg_version="$(dpkg-query -f '${Version}\n' -W "$pkg")"
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
      "user_count":   $(find /home -mindepth 1 -maxdepth 1 | wc -l)
    },
    "SSHFP": {
      "RSA":          "SHA256:7dB470mfzlyhhtqmjnXciIxp+jWLACiYKC3EE/Z0lFg",
      "ECDSA":        "SHA256:U0C6SKGXUflve16m2l4KWBdLLARW6O8TiGWZsXAU2i4",
      "ED25519":      "SHA256:V+mXTsRJ+jfJMxxPlD/28dpWouuns3Wuqwppv6ykVC8"
    },
    "system": {
      "core.$DOMAIN": {
        "location":     "myloc (Düsseldorf)",
        "os":           "$(/opt/sysinfo.sh get os)",
        "uptime":       "$(/opt/sysinfo.sh get uptime)",
        "uname":        "$(/opt/sysinfo.sh get uname)",
        "board":        "$(/opt/sysinfo.sh get board)",
        "cpuinfo":      "$(/opt/sysinfo.sh get cpuinfo)",
        "cpucount":     "$(/opt/sysinfo.sh get cpucount)"
      },
      "srv01.$DOMAIN": {
        "location":     "Hetzner (Falkenstein)",
        "os":           "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get os')",
        "uptime":       "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get uptime')",
        "uname":        "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get uname')",
        "board":        "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get board')",
        "cpuinfo":      "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get cpuinfo')",
        "cpucount":     "$(ssh srv01.$DOMAIN '/opt/sysinfo.sh get cpucount')"
      }
    },
    "services": {
      "0x0": {
        "desc":        "the null pointer - file hosting and url shortener",
        "version":     "-",
        "url":         "https://envs.sh/",
        "server":      "core.$DOMAIN"
      },
      "bbj": {
        "desc":        "bulletin butter & jelly: an http bulletin board server for small communities",
        "version":     "-",
        "url":         "https://bbj.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "cinny": {
        "desc":        "cinny is a matrix client focusing primarily on simple, elegant and secure interface.",
        "version":     "-",
        "url":         "https://cinny.$DOMAIN/",
        "server":      "srv01.$DOMAIN"
      },
      "cryptpad": {
        "desc":        "collaborative real time editing",
        "version":     "$(curl -fs https://pad."$DOMAIN"/api/config | awk -F= '/ver=/ {print $2}' | sed '$ s/"$//')",
        "url":         "https://pad.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "drone": {
        "desc":        "continuous delivery platform",
        "version":     "$(curl -fs https://drone."$DOMAIN"/version | jq -Mr .version)",
        "url":         "https://drone.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "element-web": {
        "desc":        "universal secure chat app for matrix (web-client)",
        "version":     "$(curl -fs https://element."$DOMAIN"/version)",
        "url":         "https://element.$DOMAIN/",
        "server":      "srv01.$DOMAIN"
      },
      "getwtxt": {
        "desc":        "twtxt registry service - microblogging for hackers",
        "version":     "$(curl -fs https://twtxt."$DOMAIN"/api/plain/version | awk '{print $2}')",
        "url":         "https://twtxt.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "gitea": {
        "desc":        "painless self-hosted git service",
        "version":     "$(curl -fs https://git."$DOMAIN"/api/v1/version | jq -Mr .version)",
        "url":         "https://git.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "gophernicus": {
        "desc":        "modern full-featured (and hopefully) secure gopher daemon",
        "version":     "$(/usr/local/sbin/gophernicus -v | sed 's/Gophernicus\///' | awk '{print $1}')",
        "url":         "gopher://$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "hedgedoc": {
        "desc":        "collaborative real time markdown",
        "version":     "$(curl -Is https://hedgedoc."$DOMAIN"/ | awk '/^hedgedoc-version:/{print $2}'| tr -d "\015")",
        "url":         "https://hedgedoc.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "hydrogen-web": {
        "desc":        "lightweight matrix client with legacy and mobile browser support",
        "version":     "-",
        "url":         "https://hydrogen.$DOMAIN/",
        "server":      "srv01.$DOMAIN"
      },
      "ipinfo": {
        "desc":        "ip address info",
        "version":     "-",
        "url":         "https://ip.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "jetforce": {
        "desc":        "tcp server for the gemini protocol",
        "version":     "$(/usr/local/bin/jetforce -V | awk '{printf $2}')",
        "url":         "https://gemini.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "matrix": {
        "desc":        "open network for secure, decentralized communication",
        "version":     "$(curl -fs https://matrix."$DOMAIN"/_matrix/federation/v1/version | jq -Mr .server.version)",
        "url":         "https://matrix.$DOMAIN/",
        "server":      "srv01.$DOMAIN"
      },
      "ntfy": {
        "desc":        "a simple HTTP-based pub-sub notification service",
        "version":     "$(dpkg -s ntfy | awk '/Version:/ {print $2}')",
        "url":         "https://ntfy.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "pleroma": {
        "desc":        "federated social network - microblogging",
        "version":     "$(curl -fs https://pleroma."$DOMAIN"/api/v1/instance | jq -Mr .version | awk '{print $4}' | sed '$ s/)//')",
        "url":         "https://pleroma.$DOMAIN/",
        "server":      "srv01.$DOMAIN"
      },
      "privatebin": {
        "desc":        "graphical pastebin",
        "version":     "$(lxc-attach -n pb -- bash -c "awk '/Current version:/ {print \$3}' /var/www/PrivateBin/README.md | sed 's/*$//'")",
        "url":         "https://pb.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "searxng": {
        "desc":        "privacy-respecting metasearch engine",
        "version":     "$(curl -fs https://searx."$DOMAIN"/config | jq -Mr .version)",
        "url":         "https://searx.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "thelounge": {
        "desc":        "self-hosted web irc client",
        "version":     "$(sudo -u thelounge /srv/thelounge/.yarn/bin/thelounge -v | awk -Fv '{print $2}')",
        "url":         "https://webirc.$DOMAIN/",
        "server":      "core.$DOMAIN"
      },
      "tt-rss": {
        "desc":        "tiny tiny rss - web-based news feed (rss/atom) aggregator",
        "version":     "$(lxc-attach -n rss -- bash -c "dpkg -s tt-rss | awk '/Version:/ {print \$2}' | head -n1")",
        "url":         "https://rss.$DOMAIN/",
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
      "gfu":          "$(/usr/local/bin/gfu -v | sed '/version/s/.*version \([^ ][^ ]*\)[ ]*.*/\1/')",
      "go":           "$(awk -Fgo '{print $2}' /usr/local/go/VERSION)",
      "goaccess":     "$(/usr/bin/goaccess -V | awk '/GoAccess/ {print $3}')",
      "linac":        "$(/usr/local/sbin/linac help | head -1 | awk '{print $2}')",
      "micro":        "$(/usr/local/bin/micro -version | awk '/Version/ {print $2}')",
      "pb":           "$(/usr/local/bin/pb -v)",
      "python3.13":   "$(/usr/local/bin/python3.13 --version | awk '{print $2}')",
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


#
# SYSINFO.PHP
#
print_pkg_info() {
  local pkg="$1"

  local pkg_version
  pkg_version="$(jq -Mr '.data.packages."'"$pkg"'"|select (.!=null)' "$JSON_FILE")"
  [ -z "$pkg_version" ] && pkg_version='n.a.'

  local pkg_desc
  custom_pkg_desc "$pkg"
  get_pkg_desc "$pkg"
  # remove description-en string
  pkg_desc="${pkg_desc//Description-en: /}"
  # replace double qoutes with single qoute
  pkg_desc="${pkg_desc//\"/\'}"
  # string to lowercase
  pkg_desc="${pkg_desc,,}"

  printf '\t\t<tr> <td>%s</td> <td>%s</td> <td>%s</td> </tr>\n' "$pkg" "$pkg_version" "$pkg_desc"
}

print_pkg_info_services() {
  local pkg="$1"

  local pkg_desc
  pkg_desc="$(jq -Mr '.data.services."'"$pkg"'".desc|select (.!=null)' "$JSON_FILE")"

  local pkg_version
  pkg_version="$(jq -Mr '.data.services."'"$pkg"'".version|select (.!=null)' "$JSON_FILE")"

  local s_url
  s_url="$(jq -Mr '.data.services."'"$pkg"'".url|select (.!=null)' "$JSON_FILE")"

  printf '\t\t<tr> <td><a href="%s" target="_blank">%s</a></td> <td>%s</td> <td>%s</td> </tr>\n' "$s_url" "$pkg" "$pkg_version" "$pkg_desc"
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
      # check service in sysinfo.json
      s_in_j="$(jq -Mr '.data.services."'"$pkg"'"|select (.!=null)' "$JSON_FILE")"
      if [ -n "$s_in_j" ]; then
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

  for service in "${arr[@]}"; do
    local srv_service
    srv_service="$(jq -Mr '.data.services."'"$service"'".server|select (.!=null)' "$JSON_FILE")"

    local s_url
    s_url="$(jq -Mr '.data.services."'"$service"'".url|select (.!=null)' "$JSON_FILE")"

    if [ "$srv_service" = "$srv" ]; then
      printf '<a href="%s" target="_blank">%s</a> ' "$s_url" "$service"
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
		  <tr><td><strong><?=\$local_hostname?></strong></td> <td></td></tr>
		  <tr><td>location:</td> <td>myloc (Düsseldorf)</td></tr>
		  <tr><td>os:</td> <td><?=\$local_os?></td></tr>
		  <tr><td>disk space:</td> <td>2x1TB ssd</td></tr>
		  <tr><td>services:</td> <td>$(print_srv_services 'core' "${sorted_services[@]}")</td></tr>
		  <tr><td><hr></td> <td><hr></td></tr>
		  <tr><td><strong>srv01.envs.net</strong></td> <td></td></tr>
		  <tr><td>location:</td> <td>Hetzner (Falkenstein)</td></tr>
		  <tr><td>os:</td> <td>Debian GNU/Linux 12 (bookworm)</td></tr>
		  <tr><td>disk space:</td> <td>2x3.84TB ssd-nvme | 2x12TB hdd (media storage)</td></tr>
		  <tr><td>services:</td> <td>$(print_srv_services 'srv01' "${sorted_services[@]}")</td></tr>
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
