# lib/apply.sh — profile-driven runner.
# shellcheck shell=bash

# A profile is a YAML file with a `modules:` list and per-module args.
# Example:
#   description: Minimal web VPS
#   modules:
#     - mirror:
#         provider: aliyun
#     - base: {}
#     - swap:
#         size: 2G
#     - firewall: {}
#     - fail2ban: {}
#     - timezone:
#         tz: Asia/Shanghai

_vi_resolve_profile() {
  local name="$1"
  local candidates=(
    "${VI_PROFILES_DIR_OVERRIDE:-}"
    "$VI_PROFILES_DIR_DEFAULT"
    "$VI_PROFILES_DIR_SYSTEM"
  )
  local dir
  for dir in "${candidates[@]}"; do
    [[ -z "$dir" ]] && continue
    if [[ -f "$dir/$name.yaml" ]]; then
      printf '%s/%s.yaml' "$dir" "$name"
      return 0
    fi
  done
  # Accept a direct file path too.
  if [[ -f "$name" ]]; then
    printf '%s' "$name"
    return 0
  fi
  return 1
}

vi_cmd_apply() {
  local profile=""
  local only_csv=""
  local skip_csv=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)   only_csv="${2:?--only requires a comma-separated module list}"; shift 2 ;;
      --only=*) only_csv="${1#--only=}"; shift ;;
      --skip)   skip_csv="${2:?--skip requires a comma-separated module list}"; shift 2 ;;
      --skip=*) skip_csv="${1#--skip=}"; shift ;;
      -*)       vi_err "unknown apply flag: $1"; return 2 ;;
      *)        if [[ -z "$profile" ]]; then profile="$1"; else vi_warn "ignoring extra arg: $1"; fi; shift ;;
    esac
  done

  if [[ -z "$profile" ]]; then
    vi_err "usage: vps-init apply <profile> [--only a,b,c] [--skip x,y]"
    return 2
  fi

  if [[ -n "$only_csv" && -n "$skip_csv" ]]; then
    vi_err "--only and --skip are mutually exclusive"
    return 2
  fi

  local path
  if ! path=$(_vi_resolve_profile "$profile"); then
    vi_err "profile not found: $profile"
    vi_info "looked in: $VI_PROFILES_DIR_DEFAULT and $VI_PROFILES_DIR_SYSTEM"
    return 1
  fi

  vi_step "Profile: $(basename "$path" .yaml)"
  local desc
  desc=$(grep -m1 '^description:' "$path" | sed 's/^description:[[:space:]]*//' | sed 's/^"\|"$//g')
  [[ -n "$desc" ]] && vi_info "$desc"
  [[ -n "$only_csv" ]] && vi_info "only:  $only_csv"
  [[ -n "$skip_csv" ]] && vi_info "skip:  $skip_csv"

  # Parse module entries. Each `- <name>:` at the top of `modules:` starts a
  # new step; nested 2-space keys are args. We gather them into newline-
  # separated "name|key=value|key=value" records.
  local records
  records=$(awk '
    BEGIN { in_modules = 0; current = "" }
    /^modules:/ { in_modules = 1; next }
    !in_modules { next }
    /^[^[:space:]]/ { in_modules = 0; next }
    /^[[:space:]]*-[[:space:]]+[A-Za-z][A-Za-z0-9_-]*:/ {
      if (current != "") print current
      sub(/^[[:space:]]*-[[:space:]]+/, "")
      sub(/:[[:space:]]*.*$/, "")
      current = $0
      next
    }
    /^[[:space:]]+[A-Za-z][A-Za-z0-9_-]*:/ {
      if (current == "") next
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/:[[:space:]]*/, "=", line)
      gsub(/"/, "", line)
      current = current "|" line
    }
    END { if (current != "") print current }
  ' "$path")

  if [[ -z "$records" ]]; then
    vi_err "profile has no modules: $path"
    return 1
  fi

  # Resolve --only / --skip against the profile's module list. We pre-collect
  # the modules listed and validate the filter values against them, so a typo
  # like '--only swaap' fails loudly instead of silently running nothing.
  local all_names=()
  local rec
  while IFS= read -r rec; do
    [[ -z "$rec" ]] && continue
    all_names+=("${rec%%|*}")
  done <<< "$records"

  _vi_in_csv() {
    local needle="$1" csv="$2"
    [[ -z "$csv" ]] && return 1
    local IFS=','
    local item
    for item in $csv; do
      item="${item// /}"
      [[ "$needle" == "$item" ]] && return 0
    done
    return 1
  }

  if [[ -n "$only_csv" ]]; then
    local IFS=','
    local item
    for item in $only_csv; do
      item="${item// /}"
      [[ -z "$item" ]] && continue
      local found=0
      local n
      for n in "${all_names[@]}"; do [[ "$n" == "$item" ]] && { found=1; break; }; done
      if [[ $found -eq 0 ]]; then
        vi_err "--only references module '$item' which is not in this profile"
        vi_info "profile modules: ${all_names[*]}"
        return 2
      fi
    done
  fi

  if [[ -n "$skip_csv" ]]; then
    local IFS=','
    local item
    for item in $skip_csv; do
      item="${item// /}"
      [[ -z "$item" ]] && continue
      local found=0
      local n
      for n in "${all_names[@]}"; do [[ "$n" == "$item" ]] && { found=1; break; }; done
      if [[ $found -eq 0 ]]; then
        vi_warn "--skip references module '$item' which is not in this profile (ignoring)"
      fi
    done
  fi

  local record name args
  local ran=0 skipped=0
  while IFS= read -r record; do
    [[ -z "$record" ]] && continue
    name="${record%%|*}"
    args=""
    [[ "$record" == *"|"* ]] && args="${record#*|}"

    if [[ -n "$only_csv" ]] && ! _vi_in_csv "$name" "$only_csv"; then
      vi_info "skip $name (not in --only)"
      skipped=$((skipped+1))
      continue
    fi
    if [[ -n "$skip_csv" ]] && _vi_in_csv "$name" "$skip_csv"; then
      vi_info "skip $name (in --skip)"
      skipped=$((skipped+1))
      continue
    fi

    _vi_run_module "$name" "$args"
    ran=$((ran+1))
  done <<< "$records"

  if [[ $ran -eq 0 ]]; then
    vi_warn "no modules ran (filters matched nothing)"
    return 1
  fi
  vi_ok "profile applied: $(basename "$path" .yaml) (ran $ran, skipped $skipped)"
}

# Invoke the right vi_cmd_<name> with args resolved from a key=value string.
_vi_run_module() {
  local name="$1" args_str="$2"

  # Translate args string -> positional arguments per module.
  local -a argv=()
  case "$name" in
    mirror)
      local provider=""
      if [[ "$args_str" == *"provider="* ]]; then
        provider=$(printf '%s\n' "$args_str" | tr '|' '\n' | awk -F= '/^provider=/ {print $2; exit}')
      fi
      [[ -n "$provider" ]] && argv=("$provider")
      ;;
    swap)
      local size=""
      [[ "$args_str" == *"size="* ]] && size=$(printf '%s\n' "$args_str" | tr '|' '\n' | awk -F= '/^size=/ {print $2; exit}')
      [[ -n "$size" ]] && argv=("$size")
      ;;
    timezone)
      local tz=""
      [[ "$args_str" == *"tz="* ]] && tz=$(printf '%s\n' "$args_str" | tr '|' '\n' | awk -F= '/^tz=/ {print $2; exit}')
      [[ -n "$tz" ]] && argv=("$tz")
      ;;
    node)
      local version=""
      [[ "$args_str" == *"version="* ]] && version=$(printf '%s\n' "$args_str" | tr '|' '\n' | awk -F= '/^version=/ {print $2; exit}')
      [[ -n "$version" ]] && argv=("$version")
      ;;
    base)
      if [[ "$args_str" == *"web=false"* ]]; then argv=("--no-web"); fi
      ;;
  esac

  # Source module and call.
  case "$name" in
    mirror|base|swap|timezone|firewall|fail2ban|node|docker)
      # shellcheck source=/dev/null
      source "$VI_LIB/$name.sh"
      "vi_cmd_$name" "${argv[@]}"
      ;;
    ssh-hardening|ssh)
      source "$VI_LIB/ssh.sh"
      vi_cmd_ssh
      ;;
    *)
      vi_warn "unknown module in profile: $name (skipped)"
      ;;
  esac
}
