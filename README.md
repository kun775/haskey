# haskey

Linux 系统常用命令合集，通过交互式菜单快速安装、配置和管理系统常用工具。

## 使用方法

### 直接运行
```bash
bash haskey.sh
```

### 或赋予执行权限后运行
```bash
chmod +x haskey.sh && ./haskey.sh
```

### 一键远程运行（无需克隆仓库）
```bash
bash <(curl -sL https://raw.githubusercontent.com/kun775/haskey/main/haskey.sh)
```

## 功能列表

- **zsh 管理** — 一键安装 zsh + Oh My Zsh 并设为默认 shell，配置 14 个常用主题
- **网络工具** — 查看网络配置、ping 测试、DNS 查询、端口占用、连接统计
- **系统监控** — 系统概览、CPU/内存/磁盘使用率、实时 top 监控
- **Docker 管理** — 安装 Docker、容器与镜像管理、容器操作、Docker Compose
- **开发环境** — Node.js（nvm）、Python（pyenv）、Git 配置、常用开发工具批量安装
- **Nezha 安全工具箱** — 入侵检测、SSH 安全检测、虚假 Agent 清理加固、深度取证报告

### Nezha 深度取证报告

服务器禁止 root 登录时，可用普通 sudo 用户远程一键执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/kun775/haskey/main/haskey.sh)
```

进入菜单：`Nezha 安全工具箱` → `深度取证报告`。

也可以直接运行取证脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/kun775/haskey/main/nezha-incident-check.sh | sudo ATTACKER_IP=207.58.173.192 bash
```

该脚本只读取证据，不清理、不修改系统，报告保存到 `/root/nezha-incident-report-*.txt`。

## 支持的包管理器

apt / yum / dnf / pacman / zypper，脚本会自动检测。

## 环境要求

- Linux / WSL / macOS
- bash 4.0+
- curl（远程安装和部分功能需要）

## License

MIT License
