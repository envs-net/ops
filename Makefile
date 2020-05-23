BASENAME ?= envs

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin


YELLOW = $$(tput setaf 226)
GREEN = $$(tput setaf 46)
RED = $$(tput setaf 196)
RESET = $$(tput sgr0)


install:
	@make bin etc cron fail2ban initd letsencrypt nginx ssh sysctl systemd motd var znc

uninstall:
	@make clean

clean:
	@printf "$(YELLOW)--- clean ---------------------------------------------\n$(RESET)"
	stow -t "$(BINDIR)" -D bin

	stow -t /etc/cron.d -D -d etc cron.d
	@rm -fv /etc/inetd.conf /etc/inputrc /etc/nanorc /etc/sudoers
	@rm -fv /etc/fail2ban/jail.d/envs.conf
	@rm -fv /etc/init.d/S41firewall
	@rm -fv /etc/letsencrypt/renewal-hooks/deploy/envs.sh
	stow -t /etc/nginx -D -d etc nginx
	@rm -fv /etc/security/limits.conf
	@rm -fv /etc/ssh/ssh_config /etc/ssh/sshd_config
	stow -t /etc/sysctl.d -D -d etc sysctl.d
	stow -t /etc/systemd/system -D -d etc/systemd system
	stow -t /etc/update-motd.d -D -d etc update-motd.d

	stow -t /var/ -D -d var tilde
	stow -t /var/ -D -d var signups_forbidden

	@rm -fv /srv/znc/add_znc_user.sh /srv/znc/newuser.conf.template


bin:
	@printf "$(GREEN)--- bin ------------------------------------------------\n$(RESET)"
	stow -t "$(BINDIR)" bin

etc:
	@printf "$(GREEN)--- etc ------------------------------------------------\n$(RESET)"
	@install -m 644 etc/etc/hosts /etc
	@install -m 644 etc/etc/inetd.conf /etc
	@install -m 644 etc/etc/inputrc /etc
	@install -m 644 etc/etc/nanorc /etc
	@install -m 644 etc/etc/sudoers /etc
	@install -m 644 etc/etc/security/limits.conf /etcsecurity

cron:
	@printf "$(GREEN)--- cron -----------------------------------------------\n$(RESET)"
	stow -t /etc/cron.d -d etc cron.d

fail2ban:
	@printf "$(GREEN)--- letsencrypt ----------------------------------------\n$(RESET)"
	@install -m 755 etc/fail2ban/jail.d/envs.conf /etc/fail2ban/jail.d/

initd:
	@printf "$(GREEN)--- init.d ---------------------------------------------\n$(RESET)"
	@install -m 755 etc/init.d/S41firewall /etc/init.d/

letsencrypt:
	@printf "$(GREEN)--- letsencrypt ----------------------------------------\n$(RESET)"
	@install -m 755 etc/letsencrypt/renewal-hooks/deploy/envs.sh /etc/letsencrypt/renewal-hooks/deploy/

nginx:
	@printf "$(GREEN)--- nginx ----------------------------------------------\n$(RESET)"
	@rm -rf /etc/nginx/conf.d /etc/nginx/modules-available
	stow -t /etc/nginx -d etc nginx
	@mkdir /etc/nginx/conf.d /etc/nginx/modules-available

ssh:
	@printf "$(GREEN)--- ssh ------------------------------------------------\n$(RESET)"
	@install -m 644 etc/ssh/ssh_config /etc/ssh/
	@install -m 644 etc/ssh/sshd_config /etc/ssh/

sysctl:
	@printf "$(GREEN)--- sysctl.d -------------------------------------------\n$(RESET)"
	stow -t /etc/sysctl.d -d etc sysctl.d

systemd:
	@printf "$(GREEN)--- systemd --------------------------------------------\n$(RESET)"
	stow -t /etc/systemd/system -d etc/systemd system

motd:
	@printf "$(GREEN)--- motd -----------------------------------------------\n$(RESET)"
	stow -t /etc/update-motd.d -d etc update-motd.d

var:
	@printf "$(GREEN)--- var ------------------------------------------------\n$(RESET)"
	git submodule update --remote --init -- var/tilde/admins
	make -C /var/tilde/admins/ DEST_DIR=/var/ DEST_OWNER=root DEST_GROUP=www-data
	stow -t /var var
	@chown -R root:www-data /var/signups*
	@chmod 660 /var/signups*

znc:
	@printf "$(GREEN)--- znc ------------------------------------------------\n$(RESET)"
	@install -m 755 srv/znc/add_znc_user.sh /srv/znc
	@install -m 644 srv/znc/newuser.conf.template /srv/znc
	@chown znc:znc /srv/znc/add_znc_user.sh /srv/znc/newuser.conf.template


nuke:
	@printf "$(RED)--- nuking existing files ---------------------------------\n$(RESET)"
	@rm -fv "$(BINDIR)"/conntrack.sh "$(BINDIR)"/envs_conntracks.sh
	@rm -fv "$(BINDIR)"/envs_* "$(BINDIR)"/envs_user_manage "$(BINDIR)"/welcome-email.tmpl "$(BINDIR)"/welcome-readme.tmpl
	@rm -fv "$(BINDIR)"/byobu-info "$(BINDIR)"/chat "$(BINDIR)"/dcss "$(BINDIR)"/hole "$(BINDIR)"/idiff "$(BINDIR)"/motd \
			"$(BINDIR)"/online-users "$(BINDIR)"/webirc

	@rm -fv /etc/cron.d/conntrack /etc/cron.d/envs_* /etc/cron.d/backup \
		/etc/cron.d/botany /etc/cron.d/certbot /etc/cron.d/update-blacklist /etc/cron.d/update-blacklist_fail2ban

	@rm -fv /etc/fail2ban/jail.d/envs.conf
	@rm -fv /etc/init.d/S41firewall
	@rm -fv /etc/letsencrypt/renewal-hooks/deploy/envs.sh
	@rm -rfv /etc/nginx/*
	@rm -fv /etc/security/limits.conf
	@rm -fv /etc/ssh/ssh_config /etc/ssh/sshd_config
	@rm -fv /etc/sysctl.d/10-kernel-hardening.conf /etc/sysctl.d/30-lxc-inotify.conf \
		/etc/sysctl.d/fs.conf /etc/sysctl.d/net.conf /etc/sysctl.d/panic.conf /etc/sysctl.d/protect-links.conf
	@rm -fv /etc/systemd/system/bbj.service /etc/systemd/system/gopherproxy.service \
		/etc/systemd/system/ifconfigme.service /etc/systemd/system/thelounge.service /etc/systemd/system/znc.service
	@rm -fv /etc/update-motd.d/*

	@rm -rfv /var/tilde /var/signups_forbidden /var/banned_*.txt

	@rm -fv /srv/znc/add_znc_user.sh /srv/znc/newuser.conf.template


.PHONY: install clean uninstall nuke bin etc cron fail2ban initd letsencrypt nginx ssh sysctl systemd motd var znc
