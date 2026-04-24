# lib/fail2ban.sh — install fail2ban with a tuned sshd jail.
# shellcheck shell=bash

vi_cmd_fail2ban() {
  vi_step "fail2ban"

  vi_apt_install fail2ban

  # Tuned for the reality of a VPS with a public IP in China / HK: aggressive
  # brute force traffic, long block windows cut noise meaningfully.
  local jail_local
  jail_local=$(cat <<'EOF'
# Managed by vps-init — tuned for public-internet VPS.
# Override by adding /etc/fail2ban/jail.d/99-local.conf.

[DEFAULT]
# Ignore localhost and common private ranges.
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
# Ban for 1 hour on first offense...
bantime  = 1h
# ...escalating on repeats.
bantime.increment = true
bantime.factor    = 2
bantime.maxtime   = 1w
findtime = 10m
maxretry = 5

backend = systemd

[sshd]
enabled = true
port    = ssh
mode    = aggressive
EOF
)

  vi_install_file /etc/fail2ban/jail.local "$jail_local" 0644

  vi_run systemctl enable --now fail2ban
  vi_run systemctl restart fail2ban

  if [[ "${VI_DRY_RUN:-0}" == "0" ]]; then
    fail2ban-client status >&2 || true
  fi

  vi_ok "fail2ban active with sshd jail"
}
