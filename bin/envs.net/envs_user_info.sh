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
clear_quote() { echo "$1" | sed -e '$ s/^"//' -e '$ s/"$//' ; }


progress_userarray() {
  for field in "${!line_to_set[@]}"; do
    field_name="${field//,*/}"
    field_count="${field//*,/}"

    if [[ ":${field_is_array[*]}:" =~ $field_name ]] && ! [[ ":${field_finished[*]}:" =~ $field_name ]]; then

      if [ -z "$field_in_progress" ] && [ "$field_count" -eq 0 ]; then
        # begin of user def. array
        fin_count='0'
        field_in_progress="$field_name"
        cat << EOM >> "$TMP_JSON"
        "$field_name": [
          "${line_to_set[$field]}",
EOM
      elif [ "$field_in_progress" = "$field_name" ] && [ "$field_count" = "$(( "$fin_count" + 1 ))" ]; then
        # continue user def. array
        fin_count="$(( "$fin_count" + 1 ))"
        cat << EOM >> "$TMP_JSON"
          "${line_to_set[$field]}",
EOM
        if [ "$field_count" = "${hc_field_entry[$field_name]}" ]; then
          # end of user def. array
          # remove trailing ',' on last user entry
          clear_lastline
          cat << EOM >> "$TMP_JSON"
        ],
EOM
          unset field_in_progress
          field_finished+=( "$field_name" )
        else
          progress_userarray
        fi

      elif ! [ "$field_in_progress" = "$field_name" ] && ! [[ ":${field_queue[*]}:" =~ $field_name ]]; then
        field_queue+=( "$field_name" )
      fi
    fi
  done
}


cat << EOM > "$TMP_JSON"
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
          desc="$(clear_quote "$desc")"
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
        if [ -f "$USER_HOME"/public_html/index.php ] || [ -f "$USER_HOME"/public_html/index.html ]; then
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
          count_entry='0'

          unset field_exists    ; declare -a field_exists=()    # contains field names - distinguish single from array entries
          unset field_is_array  ; declare -a field_is_array=()  # contains all array field names to printf correct json format
          unset line_to_set     ; declare -A line_to_set        # contains all user info lines
          unset hc_field_entry  ; declare -A hc_field_entry     # contains highest_count_field_entry

          # check 'INFO_FILE' and add entrys to 'line_to_set' array
          while read -r LINE ; do
            if [ -n "$LINE" ] && ! [[ "$LINE" = '#'* ]] && [[ "$LINE" = *'='* ]] \
            && ! [[ "$LINE" = 'desc='* ]] && ! [[ "$LINE" = 'ssh_pubkey='* ]]; then
              user_field="${LINE//=*/}"
              user_value="${LINE//*=/}"
              user_value="$(clear_quote "$user_value")"

              if ! [[ ":${field_exists[*]}:" =~ $user_field ]]; then
                # entry will be a single line
                field_exists+=( "$user_field" )
                count_field_entry='0'
                count_entry="$(( "$count_entry" + 1 ))" ; [ "$count_entry" -le 10 ] || continue

                line_to_set["$user_field","$count_field_entry"]+="$user_value"

              else
                # entry will be a array (max. 32 entrys)
                if ! [[ ":${field_is_array[*]}:" =~ $user_field ]]; then
                  field_is_array+=( "$user_field" )
                fi
                count_field_entry="$(( "$count_field_entry" +1 ))" ; [ "$count_field_entry" -lt 32 ] || continue
                hc_field_entry[$user_field]="$count_field_entry"

                line_to_set["$user_field","$count_field_entry"]+="$user_value"
              fi
            fi
          done < "$INFO_FILE"

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
          unset field_queue    ; declare -a field_queue=()
          unset field_finished ; declare -a field_finished=()

          if [ -n "${field_is_array[*]}" ]; then
            progress_userarray

            if [ -n "${field_queue[*]}" ]; then
              # shellcheck disable=SC2034
              for x in "${!field_queue[@]}"; do progress_userarray ; done
            fi
          fi

# ssh
          # only print ssh-pubkey if user has enabled
          ssh_pubkey="$(sed -n '/^ssh_pubkey=/{s#^.*=##;p}' "$INFO_FILE")"
          if [[ "$ssh_pubkey" =~ [yY1] ]]; then
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
          else
            # remove trailing ',' (no ssh-pubkey print out)
            clear_lastline
          fi
        else
          # no "$INFO_FILE" file
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
chown www-data:www-data "$WWW_PATH"/users_info.json


#
# user_updates.php
#

LIST="$(stat --format=%Z\ %n /home/*/public_html/* | grep -v updated | grep -v your_index_template.php | grep -v cgi-bin | sort -r)"
echo "$LIST" | perl /usr/local/bin/envs.net/envs_user_info_genpage.pl > /tmp/user_updates.php_tmp

mv /tmp/user_updates.php_tmp "$WWW_PATH"/user_updates.php
chown www-data:www-data "$WWW_PATH"/user_updates.php


#
# gemini's index.gmi
#

/usr/local/bin/envs.net/envs_gemini_genpage.sh


#
exit 0
