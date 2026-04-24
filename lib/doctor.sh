# lib/doctor.sh — report the state of the box.
# shellcheck shell=bash

vi_cmd_doctor() {
  vi_detect_distro
  vi_step "System"
  vi_info "distro:  $VI_DISTRO $VI_CODENAME"
  vi_info "uname:   $(uname -rm)"
  vi_info "uptime:  $(uptime -p 2>/dev/null || uptime)"
  vi_info "memory:  $(free -h | awk '/^Mem:/ {print $2 " total, " $3 " used, " $7 " available"}')"
  vi_info "disk /:  $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " free"}')"
  local swap
  swap=$(awk 'NR==2 {print $3}' /proc/swaps 2>/dev/null || echo 0)
  if [[ -n "$swap" && "$swap" != "0" ]]; then
    vi_info "swap:    $((swap / 1024)) MB"
  else
    vi_warn "swap:    none"
  fi

  vi_step "Services"
  for svc in nginx ssh sshd fail2ban ufw docker; do
    if systemctl list-unit-files 2>/dev/null | grep -qE "^${svc}\.service"; then
      local state
      state=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
      if [[ "$state" == "active" ]]; then
        vi_ok "$svc: $state"
      else
        vi_warn "$svc: $state"
      fi
    fi
  done

  vi_step "SSH config"
  if [[ -f /etc/ssh/sshd_config ]]; then
    for key in PasswordAuthentication PermitRootLogin PubkeyAuthentication Port; do
      local v
      v=$(awk -v k="$key" '$1 == k {print $2; exit}' /etc/ssh/sshd_config || echo "(default)")
      vi_info "$key = ${v:-(default)}"
    done
  fi

  vi_step "Tools"
  for bin in git jq curl rsync nginx certbot docker node pnpm pm2; do
    if command -v "$bin" >/dev/null 2>&1; then
      vi_ok "$bin: $(command -v "$bin")"
    fi
  done
}
