#!/usr/bin/env bash
# ssh-hardening.sh - assignment 4: harden OpenSSH on a lab Ubuntu server. Run as root, idempotent.
#   key-only login, no root, limited users, modern ciphers/MACs/KEX, short login grace, few auth tries,
#   verbose logging (so Wazuh sees every failure), and a check that the config is valid before reload.
#   sudo bash ssh-hardening.sh [allowed-user ...]       (default: labadmin)
set -eu
users=${*:-labadmin}
f=/etc/ssh/sshd_config.d/10-pel-hardening.conf
cat > "$f" <<EOF
# PEL lab SSH hardening (linux/ssh-hardening.sh)
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
AllowUsers $users
MaxAuthTries 3
MaxSessions 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
PermitTunnel no
LogLevel VERBOSE
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Banner /etc/issue.net
EOF
chmod 644 "$f"
printf 'Authorised use only. Activity on this system is logged and monitored (corp.lab).\n' > /etc/issue.net
# Ubuntu's cloud-init drop-in re-enables passwords; the first value read wins, so make sure ours sorts first
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
sshd -t
systemctl reload ssh
echo "sshd hardened; effective settings:"
sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|maxauthtries|allowusers|logingracetime|loglevel) '
