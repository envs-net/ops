#!/usr/bin/env bash
#
# envs.net - generate index.gmi
# - this script is called by /usr/local/bin/envs.net/envs_user_updated.sh
#

[ "$(id -u)" -ne 0 ] && printf 'Please run as root!\n' && exit 1

###

userlist() {
	mapfile -t users < <(jq -Mr '.data.users|keys[]' /var/www/envs.net/users_info.json)
	for USERNAME in "${users[@]}"; do
		if [ -f /home/"$USERNAME"/public_gemini/index.gmi ]; then
			[ ! -L /var/gemini/\~"$USERNAME" ] && ln -s /home/"$USERNAME"/public_gemini /var/gemini/\~"$USERNAME"
			printf '=> gemini://envs.net/~%s/ ~%s\n' "$USERNAME" "$USERNAME"
		else
			[ -L /var/gemini/\~"$USERNAME" ] && unlink /var/gemini/\~"$USERNAME"
		fi
	done
}

#
# INDEX.GMI
#
cat << EOM >> /tmp/index.gmi_tmp
welcome on envs.net - gemini
$(figlet -f smslant envs.net)
                   environments


envs.net is a minimalist, non-commercial
shared linux system and will always be free to use.

we are linux lovers, sysadmins, programmer and users who like build
webpages, write blogs, chat online, play cool console games and so much
more. you wish to join with an small user space?

join the team today!
=> https://envs.net/signup/ signup for a envs.net account (html)

visit us in gopher and html lands for more info.
=> https://envs.net website (html)
=> gopher://envs.net gophermap (gopher)


here is a list of our esteemed users:
if you are not appearing on this list, create your index.gmi in ~/public_gemini

$(userlist)

EOM


mv /tmp/index.gmi_tmp /var/gemini/index.gmi

#
exit 0
