#!/usr/bin/env bash
#
# envs.net - generate sysinfo.json and sysinfo.php
# - this script is called by /etc/cron.d/envs_sysinfo
#
WWW_PATH='/var/www/envs.net'
DOMAIN='envs.net'

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

###

# define packages by category for sysinfo.php Page
services=(0x0 bbj cryptpad getwtxt gitea gophernicus halcyon ipinfo jetforce mariadb-server matrix nginx
    openssh-server pleroma privatebin riot-web searx termbin tt-rss thelounge znc)
readarray -t sorted_services < <(printf '%s\n' "${services[@]}" | sort)


shells=(bash csh dash elvish fish ksh mksh sash tcsh xonsh yash zsh)
readarray -t sorted_shells < <(printf '%s\n' "${shells[@]}" | sort)


editors=(ed emacs micro nano neovim vim)
readarray -t sorted_editors < <(printf '%s\n' "${editors[@]}" | sort)


inet_clients=(alpine av98 bombadillo curl gomuks irssi lynx neomutt meli mutt mosh openssh-client pb toot weechat wget vf1)
readarray -t sorted_inet_clients < <(printf '%s\n' "${inet_clients[@]}" | sort)


coding_pkg=(cargo clang clisp clojure crystal default-jdk default-jre elixir erlang flex
    g++ gcc gcl gdc gforth ghc go golang guile-2.2 inform lua5.1 lua5.2 lua5.3 mono-complete
    nasm nim nodejs octave perl php picolisp ponyc python python2.7 python3 racket ruby rustc scala tcl yasm vlang)
readarray -t sorted_coding_pkg < <(printf '%s\n' "${coding_pkg[@]}" | sort)


coding_tools=(ack bison build-essential cl-launch cvs devscripts ecl gawk git gron initscripts jq latex-mk latexmk
    make mawk mercurial rake ripgrep sbcl shellcheck subversion texlive-full virtualenv yarn)
readarray -t sorted_coding_tools < <(printf '%s\n' "${coding_tools[@]}" | sort)


misc=(aria2 bc busybox burrow byobu clinte dict gfu goaccess hugo jekyll mariadb-client mandoc mathomatic mathtex mkdocs
    pandoc pelican sagemath screen sqlite3 tmux todotxt-cli twtxt txtnish zola)
readarray -t sorted_misc < <(printf '%s\n' "${misc[@]}" | sort)

#
# do not add services!
service_pkgs=(mariadb-server nginx openssh-server)
FULL_PKG_LIST=("${service_pkgs[@]}" "${shells[@]}" "${editors[@]}" "${inet_clients[@]}" "${coding_pkg[@]}" "${coding_tools[@]}" "${misc[@]}")


custom_pkg_desc() {
  local pkg="$1"
  case "$pkg" in
    # packages
    crystal)     pkg_desc='Compiler for the Crystal language';;
    # custom packages
    av98)        pkg_desc='Command line gemini client. High speed, low drag';;
    bombadillo)  pkg_desc='Bombadillo is a non-web browser for the terminal';;
    burrow)      pkg_desc='a helper for building and managing a gopher hole';;
    clinte)      pkg_desc='a community notices system';;
    gfu)         pkg_desc='A utility for formatting gophermaps';;
    go)          pkg_desc='tool for managing Go source code';;
    goaccess)    pkg_desc='fast web log analyzer and interactive viewer';;
    micro)       pkg_desc='a new modern terminal-based text editor';;
    pb)          pkg_desc='a helper utility for using 0x0 pastebin services';;
    twtxt)       pkg_desc='Decentralised, minimalist microblogging service for hackers';;
    txtnish)     pkg_desc='A twtxt client with minimal dependencies';;
    vf1)         pkg_desc='Command line gopher client. High speed, low drag.';;
    vlang)       pkg_desc='Simple, fast, safe, compiled programming language';;
    zola)        pkg_desc='single-binary static site generator written in rust';;

    *) _no_custom_pkg='1' ;;
  esac
}


#
# SYSINFO.JSON
#
JSON_FILE="$WWW_PATH/sysinfo.json"
TMP_JSON='/tmp/sysinfo.json_tmp'

print_pkg_version() {
  local pkg_version
  #for pkg in $(dpkg-query -f '${binary:Package}\n' -W); do
  for pkg in "${FULL_PKG_LIST[@]}"; do
    _no_custom_pkg='0' ; custom_pkg_desc "$pkg"

    if [ "$_no_custom_pkg" -eq '1' ] || [ "$pkg" = 'crystal' ]; then
      pkg_version="$(dpkg-query -f '${Version}\n' -W "$pkg")"

      printf '      "%s": "%s",\n' "$pkg" "$pkg_version"
    fi
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
      "website":      "https://$DOMAIN",
      "signup_url":   "https://$DOMAIN/signup/",
      "gopher":       "gopher://envs.net/",
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
      "os":           "$(lsb_release -sd)",
      "uptime":       "$(cat /proc/uptime)",
      "uname":        "$(uname -a)",
      "board":        "$(hostnamectl status | awk '/Chassis/ {print $2}')",
      "cpuinfo":      "$(awk '/system type|model name/{gsub(/^.*:[ ]*/,"");print $0;exit}' /proc/cpuinfo)",
      "cpucount":     "$(grep -c ^processor /proc/cpuinfo)"
    },
    "services": {
      "0x0": {
        "desc":        "the null pointer - file hosting and url shortener",
        "version":     "-",
        "url":         "https://envs.sh/"
      },
      "bbj": {
        "desc":        "bulletin butter & jelly: an http bulletin board server for small communities",
        "version":     "-",
        "url":         "https://bbj.envs.net/"
      },
      "cryptpad": {
        "desc":        "collaborative real time editing",
        "version":     "$(curl -fs https://pad."$DOMAIN"/api/config | awk -F= '/ver=/ {print $2}' | sed '$ s/"$//')",
        "url":         "https://pad.envs.net/"
      },
      "getwtxt": {
        "desc":        "a twtxt registry service - microblogging for hackers",
        "version":     "$(curl -fs https://twtxt."$DOMAIN"/api/plain/version | awk -Fv '{print $2}')",
        "url":         "https://twtxt.envs.net/"
      },
      "gitea": {
        "desc":        "a painless self-hosted git service written in go",
        "version":     "$(lxc-attach -n gitea -- bash -c "gitea --version | awk '{print \$3}'")",
        "url":         "https://git.envs.net/"
      },
      "gophernicus": {
        "desc":        "a modern full-featured (and hopefully) secure gopher daemon",
        "version":     "$(/usr/sbin/gophernicus -v | sed 's/Gophernicus\///' | awk '{print $1}')",
        "url":         "gopher://envs.net/"
      },
      "halcyon": {
        "desc":        "a webclient for mastodon and pleroma which looks like twitter",
        "version":     "$(cat /var/lib/lxc/pleroma/rootfs/var/www/halcyon/version.txt)",
        "url":         "https://halcyon.envs.net/"
      },
      "ipinfo": {
        "desc":        "ip address info",
        "version":     "-",
        "url":         "https://ip.envs.net/"
      },
      "jetforce": {
        "desc":        "an tcp server for the gemini protocol",
        "version":     "$(/usr/local/bin/jetforce -V | awk '{printf $2}')",
        "url":         "gemini://envs.net/"
      },
      "matrix": {
        "desc":        "an open network for secure, decentralized communication",
        "version":     "$(curl -fs https://matrix."$DOMAIN"/_matrix/federation/v1/version | jq -Mr .server.version)",
        "url":         "https://matrix.envs.net/"
      },
      "pleroma": {
        "desc":        "federated social network - microblogging",
        "version":     "$(curl -fs https://pleroma."$DOMAIN"/api/v1/instance | jq -Mr .version | awk '{print $4}' | sed '$ s/)//')",
        "url":         "https://pleroma.envs.net/"
      },
      "privatebin": {
        "desc":        "a graphical pastebin",
        "version":     "$(lxc-attach -n pb -- bash -c "awk '/Current version:/ {print \$3}' /var/www/PrivateBin/README.md | sed '$ s/*$//'")",
        "url":         "https://pb.envs.net/"
      },
      "riot-web": {
        "desc":        "a universal secure chat app for matrix (web-client)",
        "version":     "$(lxc-attach -n matrix -- bash -c "dpkg-query -f '\${Version}\n' -W riot-web")",
        "url":         "https://matrix.envs.net/"
      },
      "searx": {
        "desc":        "a privacy-respecting metasearch engine",
        "version":     "$(curl -fs https://searx."$DOMAIN"/config | jq -Mr .version)",
        "url":         "https://searx.envs.net/"
      },
      "termbin": {
        "desc":        "netcat-based command line pastebin",
        "version":     "-",
        "url":         "https://tb.envs.net/"
      },
      "thelounge": {
        "desc":        "a self-hosted web irc client",
        "version":     "$(sudo -u thelounge /srv/thelounge/.yarn/bin/thelounge -v | awk -Fv '{print $2}')",
        "url":         "https://webirc.envs.net/"
      },
      "tt-rss": {
        "desc":        "tiny tiny rss - web-based news feed (rss/atom) aggregator",
        "version":     "$(lxc-attach -n rss -- bash -c "dpkg -s tt-rss | awk '/Version:/ {print \$2}' | head -n1")",
        "url":         "https://rss.envs.net/"
      },
      "znc": {
        "desc":        "advanced modular irc bouncer",
        "version":     "$(dpkg -s znc | awk '/Version:/ {print $2}' | head -n1)",
        "url":         "https://znc.envs.net/"
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
      "micro":        "$(/usr/local/bin/micro -version | awk '/Version/ {print $2}')",
      "pb":           "$(/usr/local/bin/pb -v)",
      "twtxt":        "$(/usr/local/bin/twtxt --version | awk '/version/ {printf $3}')",
      "txtnish":      "$(/usr/local/bin/txtnish -V)",
      "vf1":          "$(/usr/local/bin/vf1 --version | awk '/VF-1/ {print $2}')",
      "vlang":        "$(/usr/local/bin/v --version | awk '/V/ {print $2}')",
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
chown root:www-data "$JSON_FILE"


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
  [ -z "$pkg_desc" ] && pkg_desc="$(apt-cache show "$pkg" | awk '/Description-en/ {print substr($0, index($0,$2))}' | head -1)"
  [ -z "$pkg_desc" ] && pkg_desc="$(apt-cache search ^"$pkg"$ | awk '{print substr($0, index($0,$3))}')"
  [ -z "$pkg_desc" ] && pkg_desc='n.a.'
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

  printf '\t<table class="table_pkg">\n'
  printf '\t\t<tr> <th class="tw140">Package</th> <th class="tw280">Version</th> <th>Description</th> </tr>\n'

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


cat<<EOM > /tmp/sysinfo.php_tmp
<?php
// do not touch
// this files is generated by /usr/local/bin/envs.net/envs_sysinfo.sh
  \$title = "$DOMAIN | sysinfo";
  \$desc = "$DOMAIN | sysinfo";

include 'header.php';
?>

  <body id="body" class="dark-mode">
  <div>

    <div class="button_back">
    <pre class="clean"><strong><a href="/">&lt; back</a></strong></pre>
    </div>

    <div id="main">
<div class="block">
<h1><em>sysinfo</em></h1>
<pre>
<em>full data source: <a href="/sysinfo.json">https://$DOMAIN/sysinfo.json</a></em>
<em>webserver stats: <a href="/stats/">https://$DOMAIN/stats/</a></em>

<em>server admin: <a href="/~creme/">&#126;creme</a></em>
</pre>
<p></p>
</div>

<pre>
this is a static list of the package informations. it updates once per day.

<strong>&#35; can i get [package] installed?</strong>
probably! send an email with your suggestion to <a href="mailto:sudoers@$DOMAIN">sudoers@$DOMAIN</a>.

</pre>

$(print_category 'services' "${sorted_services[@]}")
$(print_category 'shells' "${sorted_shells[@]}")
$(print_category 'editors' "${sorted_editors[@]}")
$(print_category 'online_browser_and_clients' "${sorted_inet_clients[@]}")
$(print_category 'coding_packages' "${sorted_coding_pkg[@]}")
$(print_category 'coding_tools' "${sorted_coding_tools[@]}")
$(print_category 'misc' "${sorted_misc[@]}")
    </div>

<?php include 'footer.php'; ?>

EOM

mv /tmp/sysinfo.php_tmp "$WWW_PATH"/sysinfo.php
chown root:www-data "$WWW_PATH"/sysinfo.php

#
exit 0
