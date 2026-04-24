# lib/ssh.sh — harden sshd: disable root password + password auth when a key
# is already present.
# shellcheck shell=bash

vi_cmd_ssh() {
  vi_step "SSH hardening"

  local config=/etc/ssh/sshd_config
  if [[ ! -f "$config" ]]; then
    vi_err "$config not found — is OpenSSH installed?"
    return 1
  fi

  # Safety check: refuse to disable password auth if no authorized_keys exists
  # anywhere. Otherwise we can lock the operator out.
  local has_key=0
  for u in root $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    local home; home=$(getent passwd "$u" | cut -d: -f6)
    if [[ -n "$home" && -s "$home/.ssh/authorized_keys" ]]; then
      has_key=1
      vi_info "found keys for user: $u"
    fi
  done

  if [[ $has_key -eq 0 ]]; then
    vi_err "refusing to disable password auth: no authorized_keys found for any user"
    vi_info "add your key to ~/.ssh/authorized_keys first, then re-run"
    return 1
  fi

  vi_backup_file "$config"
  vi_set_conf "$config" "PasswordAuthentication" "no"
  vi_set_conf "$config" "PermitRootLogin" "prohibit-password"
  vi_set_conf "$config" "PubkeyAuthentication" "yes"
  vi_set_conf "$config" "ChallengeResponseAuthentication" "no"
  vi_set_conf "$config" "KbdInteractiveAuthentication" "no"
  vi_set_conf "$config" "UsePAM" "yes"
  vi_set_conf "$config" "ClientAliveInterval" "300"
  vi_set_conf "$config" "ClientAliveCountMax" "2"

  vi_run sshd -t
  vi_run systemctl reload ssh || vi_run systemctl reload sshd
  vi_ok "sshd hardened"
}
