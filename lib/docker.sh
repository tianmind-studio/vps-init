# lib/docker.sh — install Docker CE from Docker's own repo.
# shellcheck shell=bash

vi_cmd_docker() {
  vi_detect_distro
  if [[ "$VI_DISTRO" == "unsupported" ]]; then
    vi_err "unsupported distribution"
    return 1
  fi

  vi_step "Docker CE"

  if command -v docker >/dev/null 2>&1; then
    vi_info "docker already installed: $(docker --version)"
    return 0
  fi

  vi_apt_install ca-certificates curl gnupg

  # Docker's signing key.
  vi_run install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    vi_run bash -c "curl -fsSL https://download.docker.com/linux/$VI_DISTRO/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    vi_run chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Repo.
  local repo="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$VI_DISTRO $VI_CODENAME stable"
  vi_install_file /etc/apt/sources.list.d/docker.list "$repo" 0644

  vi_run apt-get update
  vi_apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  vi_run systemctl enable --now docker

  # Add the invoking user (if not root) to the docker group for convenience.
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    vi_run usermod -aG docker "$SUDO_USER"
    vi_info "added $SUDO_USER to docker group (re-login required)"
  fi

  vi_ok "docker ready"
}
