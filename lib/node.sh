# lib/node.sh — install Node via nvm, plus pnpm + pm2 globally.
# shellcheck shell=bash

vi_cmd_node() {
  local version="${1:-lts}"

  vi_step "Node (nvm)"

  local target_user="${SUDO_USER:-$USER}"
  local target_home
  target_home=$(getent passwd "$target_user" | cut -d: -f6)
  if [[ -z "$target_home" ]]; then
    vi_err "could not resolve home for user: $target_user"
    return 1
  fi

  local nvm_dir="$target_home/.nvm"
  local nvm_version="v0.39.7"

  # Install nvm if missing.
  if [[ ! -d "$nvm_dir" ]]; then
    vi_info "installing nvm $nvm_version -> $nvm_dir"
    vi_run sudo -u "$target_user" -H bash -c "
      export NVM_DIR='$nvm_dir'
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh | bash
    "
  else
    vi_info "nvm already present"
  fi

  # Install node + pnpm + pm2. Use a login-ish shell so nvm is sourced.
  local node_expr
  case "$version" in
    lts|LTS) node_expr="--lts" ;;
    *)       node_expr="$version" ;;
  esac

  vi_run sudo -u "$target_user" -H bash -c "
    export NVM_DIR='$nvm_dir'
    # shellcheck disable=SC1091
    . \$NVM_DIR/nvm.sh
    nvm install $node_expr
    nvm alias default $node_expr
    corepack enable || true
    npm install -g pnpm pm2
  "

  vi_ok "node ready (nvm + pnpm + pm2) for user $target_user"
  vi_info "re-login or 'source \$NVM_DIR/nvm.sh' to pick up in the current shell"
}
