#!/usr/bin/env bash
#
# envs.net - this script generates the following static sites
#   - users_info.json
#   - user_updates.php
#   - gemini's index.gmi
#
# this script is called by /etc/cron.d/envs_user_info
#
WWW_PATH='/var/www/envs.net'
DOMAIN="envs.net"

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

#
# users_info.json
#
TMP_JSON='/tmp/users_info.json_tmp'

clear_lastline() { sed -i '$ s/,$//' "$TMP_JSON" ; }

cat << EOM > "$TMP_JSON"
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
    "users": {
EOM
# user header
    for USERNAME in /home/*
    do
      USER_HOME="$USERNAME"
      USERNAME="${USERNAME/\/home\//}"
      INFO_FILE="$USER_HOME/.envs"

      cat << EOM >> "$TMP_JSON"
      "$USERNAME": {
        "home":        "$USER_HOME",
        "email":       "$USERNAME@$DOMAIN",
EOM
# desc
        if [ -f "$INFO_FILE" ]; then
          desc="$(sed -n '/^desc=/{s#^.*=##;p}' "$INFO_FILE")"
          if [ -z "$desc" ] || [ "$desc" == 'a short describtion or message' ]; then
            cat << EOM >> "$TMP_JSON"
        "desc":        "",
EOM
          else
          cat << EOM >> "$TMP_JSON"
        "desc":        "$desc",
EOM
          fi
        else
          cat << EOM >> "$TMP_JSON"
        "desc":        "",
EOM
        fi
# website
        if [ -f "$USER_HOME"/public_html/index.php ] || [ "$(test -f "$USER_HOME"/public_html/index.*htm*; echo $?)" -eq 0 ]; then
          cat << EOM >> "$TMP_JSON"
        "website":     "https://$DOMAIN/~$USERNAME/",
EOM
        else
          cat << EOM >> "$TMP_JSON"
        "website":     "",
EOM
        fi
# gopher
        if [ -f "$USER_HOME"/public_gopher/gophermap ]; then
          cat << EOM >> "$TMP_JSON"
        "gopher":      "gopher://$DOMAIN/1/~$USERNAME/",
        "gopherproxy": "https://gopher.$DOMAIN/$DOMAIN/1/~$USERNAME/",
EOM
        else
          cat << EOM >> "$TMP_JSON"
        "gopher":      "",
        "gopherproxy": "",
EOM
        fi
# gemini
        if [ -f "$USER_HOME"/public_gemini/index.gmi ]; then
          cat << EOM >> "$TMP_JSON"
        "gemini":      "gemini://$DOMAIN/~$USERNAME/",
EOM
        fi
# blog
        if [ "$(find "$USER_HOME"/public_html/blog/ -maxdepth 1 2>/dev/null | wc -l)" -ge 3 ]; then
          cat << EOM >> "$TMP_JSON"
        "blog":        "https://$DOMAIN/~$USERNAME/blog/",
EOM
        else
          cat << EOM >> "$TMP_JSON"
        "blog":        "",
EOM
        fi
# twtwt
        if [ -f "$USER_HOME"/public_html/twtxt.txt ]; then
          cat << EOM >> "$TMP_JSON"
        "twtxt":       "https://$DOMAIN/~$USERNAME/twtxt.txt",
EOM
        else
          cat << EOM >> "$TMP_JSON"
        "twtxt":       "",
EOM
        fi
# user custom infos from .envs file (max. 10 entrys)
        if [ -f "$INFO_FILE" ]; then
          count_entry='0'               # use to limit entrys
          count_field_entry='0'         # use to separat array line by line

          unset field_exists; declare -a field_exists=()      # contains field names to limit entrys
          unset field_is_array; declare -a field_is_array=()  # contains array fields to printf correct json entrys
          unset line_to_set; declare -A line_to_set           # contains user info lines

          # check 'INFO_FILE' and add entrys to 'line_to_set' array
          while read -r LINE ; do
            if [[ -n "$LINE" ]] && ! [[ "$LINE" = '#'* ]] \
            && ! [[ "$LINE" = 'desc='* ]] && ! [[ "$LINE" = 'ssh_pubkey='* ]]; then
              user_field="${LINE//=*/}"
              user_value="${LINE//*=/}"

              if ! [[ ":${field_exists[*]}:" =~ $user_field ]]; then
                # entry will be a single line
                count_entry="$(( "$count_entry" + 1 ))"; [ "$count_entry" -le '10' ] || continue
                field_exists+=( "$user_field" )
                line_to_set["$user_field","$count_field_entry"]+="$user_value"
              else
                # entry will be a array
                if ! [[ ":${field_is_array[*]}:" =~ $user_field ]]; then
                  field_is_array+=( "$user_field" )
                fi
                count_field_entry="$(( "$count_field_entry" +1 ))"
                line_to_set["$user_field","$count_field_entry"]+="$user_value"
              fi
            fi
          done <<< "$(tac "$INFO_FILE")" # read file from buttom

          # add users custom entrys from line_to_set (single lines before arrays)
          #
          # single line entrys
          for field in "${!line_to_set[@]}"; do
            field_name="${field//,*/}"

            if ! [[ ":${field_is_array[*]}:" =~ $field_name ]]; then
              cat << EOM >> "$TMP_JSON"
        "$field_name": "${line_to_set[$field]}",
EOM
            fi
          done
          #
          # array line entrys
          field_in_progress=''

          for field in "${!line_to_set[@]}"; do
            field_name="${field//,*/}"
            field_count="${field//*,/}"

            if [[ ":${field_is_array[*]}:" =~ $field_name ]]; then
              # begin of user def. array
              if ! [ "$field_in_progress" = "$field_name" ]; then
                field_in_progress="$field_name"

                cat << EOM >> "$TMP_JSON"
        "$field_name": [
          "${line_to_set[$field]}",
EOM
              else
                # continue user def. array
                cat << EOM >> "$TMP_JSON"
          "${line_to_set[$field]}",
EOM
                if [ "$field_count" -eq '0' ]; then
                  # end of user def. array
                  # remove trailing ',' on last user entry
                  unset field_in_progress
                  clear_lastline
                  cat << EOM >> "$TMP_JSON"
        ],
EOM
                fi
              fi
            fi
          done
        fi
# ssh
        # only print ssh-pubkey if user has enabled
        if [ -f "$INFO_FILE" ]; then
          ssh_pubkey="$(sed -n '/^ssh_pubkey=/{s#^.*=##;p}' "$INFO_FILE")"
          case "$ssh_pubkey" in
            y|Y|1 )
              cat << EOM >> "$TMP_JSON"
        "ssh-pubkey": [
EOM
              while read -r LINE ; do
                [[ "$LINE" == 'ssh'* ]] && printf '          "%s",\n' "$LINE" >> "$TMP_JSON"
              done < "$USER_HOME"/.ssh/authorized_keys
              # remove trailing ',' for the last pubkey
              clear_lastline

            # close user ssh pubkey array
            cat << EOM >> "$TMP_JSON"
        ]
EOM
            ;;
            *) clear_lastline ;;
          esac
        else
          # remove trailing ',' for the last user entry
          clear_lastline
        fi
        # close user part.
        cat << EOM >> "$TMP_JSON"
      },
EOM
# EOF
    done
    # remove trailing ',' for last user
    clear_lastline

    cat << EOM >> "$TMP_JSON"
    }
  }
}
EOM


mv "$TMP_JSON" "$WWW_PATH"/users_info.json
chown root:www-data "$WWW_PATH"/users_info.json


#
# user_updates.php
#

LIST="$(stat --format=%Z\ %n /home/*/public_html/* | grep -v updated | grep -v your_index_template.php | grep -v cgi-bin | sort -r)"
echo "$LIST" | perl /usr/local/bin/envs.net/envs_user_info_genpage.pl > /tmp/user_updates.php_tmp

mv /tmp/user_updates.php_tmp "$WWW_PATH"/user_updates.php
chown root:www-data "$WWW_PATH"/user_updates.php


#
# gemini's index.gmi
#

/usr/local/bin/envs.net/envs_gemini_genpage.sh


#
exit 0
