# Security policy

## Reporting a vulnerability

If you believe you've found a security-relevant bug in vps-init, please
do **not** open a public issue. Instead, email:

**wx@tianmind.com**

with "vps-init security:" in the subject. Include:

- A description of the issue.
- The exact module / command affected.
- The impact (privilege escalation, unintended port exposure, credential
  leak, weakened SSH / firewall / fail2ban config).

You should get a reply within 3 business days.

## What is in scope

- Any module that opens a network port, disables a hardening step, or
  grants privilege in a way the documentation doesn't describe.
- The SSH-hardening safeguard that refuses to disable password auth when no
  user has `authorized_keys` — any way to bypass or mislead this check.
- The `user` module writing SSH keys or sudoers entries that grant access
  to an unintended principal.
- `postgres` / `mysql` modules exposing the DB beyond localhost.

## What is not in scope

- Operator running `--sudo-nopasswd` intentionally and losing their laptop.
- Compromise of the distro's apt / PGDG / docker.com repositories upstream.
- DoS via the operator running `vps-init apply` twice without `--yes`.

## Disclosure

Coordinated. Reporters who ask will be credited in the release notes.
