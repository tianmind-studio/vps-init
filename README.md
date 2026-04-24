<h1 align="center">vps-init</h1>
<p align="center">
  <b>一条命令把一台全新 Ubuntu/Debian VPS 初始化为可用生产环境 · 为中国大陆 / 香港 VPS 做过针对性调优</b><br/>
  <sub>One-command, idempotent VPS bootstrap tuned for China-mainland and HK servers.</sub>
</p>

<p align="center">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="MIT"/></a>
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu"/>
  <img src="https://img.shields.io/badge/Debian-12-A81D33?style=flat-square&logo=debian&logoColor=white" alt="Debian"/>
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/status-v0.1.0-0A66C2?style=flat-square" alt="Version"/>
</p>

---

## 这东西是什么 · What this is

每次拿到一台新 VPS，你都要：

1. 换 apt 源（国内走官方源下载等到天荒地老）
2. 装一堆基础工具（nginx / certbot / git / jq / htop...）
3. 加 swap（1核1G VPS 不加 swap，打开 systemd-journald 都要死机）
4. 配时区（默认 UTC，日志看得累）
5. 开 UFW + fail2ban（公网扫描每秒敲你几次）
6. 关闭密码登录（迟早被爆破）

每一步都是网上搜一遍、抄一下、试一下、踩一个坑、再换一个写法。`vps-init` 把这一整套做成**幂等、可预览、可分步、可回滚** 的命令行工具，**针对中国大陆/香港 VPS 做了实际踩出来的调优**。

---

## 30 秒上线 · 30-second onboarding

在一台新 Ubuntu 22.04 / 24.04 或 Debian 12 上：

```bash
# 1. 下载
git clone https://github.com/491034170/vps-init /opt/vps-init
ln -sf /opt/vps-init/bin/vps-init /usr/local/bin/vps-init

# 2. 看看会发生什么（不执行）
sudo vps-init --dry-run apply web-cn

# 3. 真正执行（web-cn 适合跑 nginx 网站的场景）
sudo vps-init apply web-cn

# 完事。此时这台机器上：
# - 时区 Asia/Shanghai
# - apt 源切到阿里云
# - nginx + certbot + git + jq 等基础工具装好
# - 2G swap + vm.swappiness=10
# - UFW 放行 22/80/443
# - fail2ban 带加重型 bantime 保护 sshd
# - ssh 关了密码登录，只允许 key（前提：你已经放好 authorized_keys）
```

---

## 内置 profile · Built-in profiles

| profile       | 用途 |
|---------------|------|
| `minimal`     | 最小化 bootstrap：时区 + 国内源 + 基础工具（不装 nginx）+ swap。不动防火墙、不改 SSH。适合只想换源+加 swap 的老机器。 |
| `web-cn`      | 完整 web VPS：时区 + 国内源 + nginx/certbot + swap + UFW + fail2ban + ssh 加固。**最常用**，配 `site-bootstrap` 刚刚好。 |
| `node-app`    | `web-cn` + Node.js（nvm / pnpm / pm2），适合跑 Next.js / Nuxt / Express 应用。 |
| `docker-host` | Docker CE 宿主机：不装 nginx，装 Docker，开防火墙、加固 SSH。 |

列出全部：`vps-init list`。

---

## 单独模块 · Standalone modules

每个模块都能单独跑，幂等，可 `--dry-run`：

```bash
sudo vps-init mirror aliyun        # 换阿里云源
sudo vps-init swap 2G              # 加 2G swap
sudo vps-init timezone Asia/Shanghai
sudo vps-init firewall             # UFW 默认策略
sudo vps-init fail2ban             # 带 bantime escalation 的 sshd jail
sudo vps-init ssh-hardening        # 关密码登录（有保护：没 key 会拒绝）
sudo vps-init node lts             # nvm + pnpm + pm2
sudo vps-init docker               # Docker CE from docker.com

# 建操作员账户（拉你 GitHub 上的 pub key 直接装上）：
sudo vps-init user deploy --github your-gh-handle --sudo-nopasswd

vps-init doctor                    # 看一眼当前机器状态
```

镜像可选：`aliyun` / `tuna`（清华）/ `ustc`（中科大）/ `163`（网易）/ `huaweicloud`。

---

## 中国场景做了哪些特别优化 · China-specific tuning

1. **apt 源切换同时支持两种格式**：Ubuntu 24.04 用新的 deb822 `ubuntu.sources`，旧版本用 `sources.list`，自动识别。
2. **默认走阿里云镜像**（可换清华/中科大）。多次 bench 下来，阿里云对国内 VPS 节点延迟最稳。
3. **fail2ban 开 `bantime.increment`**：对公网扫爆破流量更有效。中国/香港 VPS 被扫的量级比欧美 VPS 高一个数量级，单次 10 分钟的 bantime 根本不够。
4. **swap 默认 `vm.swappiness=10`**：小内存 VPS 用默认 60 会疯狂换页，体感明显。
5. **Docker 从 docker.com 官方源装，不走 `apt install docker.io`**：后者版本落后、不带 buildx 和 compose plugin。
6. **SSH 加固带安全检查**：如果所有用户都没 `authorized_keys`，拒绝关闭密码登录，避免把自己锁在外面。

---

## 设计原则 · Design principles

**一、幂等。** 每个模块都可以重复运行。改 config 前会打时间戳备份；写 config 先比较内容再决定动不动。

**二、透明。** `--dry-run` 会把每一条要执行的命令都打印出来。看完再决定跑不跑。

**三、零 agent。** 不装 daemon、不开后台进程。干完就退出。

**四、一次只做一件事。** 模块之间互相独立，也可以单独跑。profile 只是一串模块的调用顺序。

**五、可以自带 profile。** 默认 profile 在 `./profiles/`，你可以在 `/etc/vps-init/profiles/` 放自己的企业版 profile，或者直接给 `apply` 传 yaml 文件路径。

---

## 系统要求

- Ubuntu 22.04 / 24.04 LTS 或 Debian 12
- Bash 4+、`apt`、`systemctl`
- 有 sudo 权限（大部分命令需要 root）

其它发行版（CentOS / Rocky / Arch）**不支持**。想要支持请在 issues 留言。

---

## Roadmap

- [x] `user` 模块：创建非 root 用户 + 免密 sudo + 导入 key（0.1.1）
- [ ] `apply` 增加 `--skip` / `--only` 开关，可绕过或只跑某几个模块
- [ ] `postgres` / `mysql` 模块（阿里云源 + 合理默认）
- [ ] `--profile-dir` 查找顺序优先级更细致的文档
- [ ] GitHub Actions 跑 `shellcheck` 基础上加上 `bats` 单测（lxc 容器里跑各模块）

---

## Contributing

Bug reports / profile PRs 都欢迎。请附上：

- 发行版版本（`lsb_release -a`）
- 具体命令和 `--verbose` 输出（如果有）
- 如果是模块 PR，写清楚"幂等怎么保证的"

## License

MIT © 2026 Tianmind Studio. See [LICENSE](./LICENSE).

<sub>Works great with <a href="https://github.com/491034170/site-bootstrap">site-bootstrap</a> — <code>vps-init apply web-cn</code> gets your server ready, <code>site-bootstrap deploy</code> ships your site.</sub>
