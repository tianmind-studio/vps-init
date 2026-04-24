# lib/user.sh — create an unprivileged operator user with sudo and SSH access.
# shellcheck shell=bash

vi_cmd_user() {
  local name="${1:-}"
  shift || true

  local shell="/bin/bash"
  local sudo_nopasswd=0
  local key_from=""
  local key_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --shell)           shell="$2"; shift 2 ;;
      --sudo-nopasswd)   sudo_nopasswd=1; shift ;;
      --copy-key-from)   key_from="$2"; shift 2 ;;
      --key-file)        key_file="$2"; shift 2 ;;
      --github)          # shorthand: pull keys from github.com/<user>.keys
                         key_from="github:$2"; shift 2 ;;
      *) vi_warn "unknown flag: $1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    vi_err "usage: vps-init user <name> [--copy-key-from <user>] [--key-file <path>] [--github <gh-login>] [--sudo-nopasswd]"
    return 2
  fi

  # Username hygiene: POSIX-ish only. No "admin" or "root" (footguns).
  if [[ ! "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    vi_err "invalid username: $name (must match [a-z_][a-z0-9_-]{0,31})"
    return 2
  fi
  if [[ "$name" == "root" ]]; then
    vi_err "refusing to manage the root user"
    return 1
  fi

  vi_step "User: $name"

  # Create the user if missing; idempotent.
  if id "$name" >/dev/null 2>&1; then
    vi_info "user $name already exists — will reconcile settings"
  else
    vi_run useradd -m -s "$shell" "$name"
    vi_ok "created user $name"
  fi

  # Sudoers drop-in (per-user file so we don't touch /etc/sudoers).
  local sudoers_file="/etc/sudoers.d/90-$name"
  if [[ $sudo_nopasswd -eq 1 ]]; then
    vi_install_file "$sudoers_file" "$name ALL=(ALL) NOPASSWD:ALL" 0440
    vi_run visudo -cf "$sudoers_file"
  else
    vi_install_file "$sudoers_file" "$name ALL=(ALL) ALL" 0440
    vi_run visudo -cf "$sudoers_file"
  fi

  # Home + .ssh directory.
  local home
  home=$(getent passwd "$name" | cut -d: -f6)
  vi_run install -d -m 0700 -o "$name" -g "$name" "$home/.ssh"

  local auth_file="$home/.ssh/authorized_keys"

  # Key source resolution order: --key-file > --copy-key-from (root) > --github.
  local key_data=""
  if [[ -n "$key_file" ]]; then
    if [[ ! -f "$key_file" ]]; then
      vi_err "key file not found: $key_file"; return 1
    fi
    key_data=$(cat "$key_file")
  elif [[ -n "$key_from" ]]; then
    if [[ "$key_from" == github:* ]]; then
      local gh_user="${key_from#github:}"
      vi_info "fetching github.com/$gh_user.keys"
      key_data=$(curl -fsSL "https://github.com/$gh_user.keys" || true)
      if [[ -z "$key_data" ]]; then
        vi_err "no keys returned from github.com/$gh_user.keys"
        return 1
      fi
    else
      local src_home
      src_home=$(getent passwd "$key_from" | cut -d: -f6)
      if [[ -z "$src_home" || ! -s "$src_home/.ssh/authorized_keys" ]]; then
        vi_err "no authorized_keys to copy from user: $key_from"
        return 1
      fi
      key_data=$(cat "$src_home/.ssh/authorized_keys")
    fi
  fi

  if [[ -n "$key_data" ]]; then
    if [[ "${VI_DRY_RUN:-0}" == "1" ]]; then
      vi_info "(dry-run) would install $(printf '%s\n' "$key_data" | wc -l | tr -d ' ') key(s) for $name"
    else
      vi_backup_file "$auth_file"
      # Append without duplicating existing keys.
      touch "$auth_file"
      local key
      while IFS= read -r key; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        if ! grep -qxF "$key" "$auth_file"; then
          printf '%s\n' "$key" >> "$auth_file"
        fi
      done <<< "$key_data"
      chown "$name:$name" "$auth_file"
      chmod 0600 "$auth_file"
      vi_ok "authorized_keys updated: $auth_file"
    fi
  else
    vi_warn "no SSH key provided — user $name cannot log in yet"
    vi_info "add one with: vps-init user $name --key-file /path/to/key.pub"
    vi_info "           or: vps-init user $name --github your-gh-handle"
  fi

  vi_ok "user $name ready"
}
