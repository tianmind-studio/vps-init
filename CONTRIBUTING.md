# Contributing to vps-init

## Reality check first

`vps-init` is deliberately narrow: Ubuntu 22.04 / 24.04 + Debian 12, with
opinions tuned to CN / HK VPS scenarios. Feature proposals that take it
outside that scope (CentOS / RHEL / Arch / cloud-init replacement / config
management framework) will be declined. There are already excellent tools
for those use cases.

## Bug reports

Please include:

1. `lsb_release -a` output.
2. The exact command, with `--verbose` where available.
3. Full output — especially the failing apt / systemctl line.
4. The profile YAML if you used `apply`.

## Feature requests

Open an issue. For new modules, write **why the default Ubuntu/Debian
install needs it** — ideally with a reference to a real pain point you hit
on a CN/HK VPS.

Proposals likely to be accepted:

- A new China-region mirror that is measurably faster than aliyun on some ISP.
- A new fail2ban jail for a commonly-exposed service (postfix, postgres).
- A new module in a clean 1-file-1-module style with full `--dry-run` support.

Proposals likely to be declined:

- Generalizing to non-apt distros.
- Replacing shell with Python / Go / Ansible.
- Adding persistent agent / daemon of any kind.

## Code style

- Bash only. Functions prefixed `vi_cmd_<module>`.
- Every module must be **idempotent**. Prove it: running the same command
  twice should produce identical end state, with the second run doing ~no
  work and making ~no output changes.
- Every edit to a config file must go through `vi_backup_file` first.
- Every mutation must be wrapped in `vi_run` so `--dry-run` works.
- `shellcheck` must pass (`-e SC1091 -e SC2155`).

## Testing locally

Easiest way: an LXC / systemd-nspawn container.

```bash
lxc launch ubuntu:24.04 vps-init-test
lxc file push -r . vps-init-test/root/vps-init/
lxc exec vps-init-test -- bash -c '
  chmod +x /root/vps-init/bin/vps-init
  ln -sf /root/vps-init/bin/vps-init /usr/local/bin/vps-init
  vps-init --dry-run apply web-cn
'
```

For modules that don't care about distro specifics, macOS with `bash` 4+
is fine for `--dry-run` checks.

## Commit messages

Conventional commits: `feat(module): ...`, `fix(module): ...`. When adding a
whole new module, `feat(<module>): initial implementation`.

## License

Submissions are MIT-licensed.
