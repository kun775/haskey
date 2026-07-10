#!/bin/bash

###############################################################################
# haskey.sh — Linux 系统常用命令合集
# 功能：快速安装、配置和显示 Linux 系统常用工具
# 作者：kun775
# 版本：v1.1.0
# 版权：MIT License
# 仓库：https://github.com/kun775/haskey
###############################################################################

# ========================== 颜色定义 ==========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ========================== 工具函数 ==========================

# 打印分隔线
print_line() {
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

# 打印标题
print_title() {
    clear
    echo ""
    print_line
    echo -e "${BOLD}${GREEN}  $1${NC}"
    print_line
    echo ""
}

# 打印提示信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测包管理器
detect_pkg_manager() {
    if command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt install -y"
        PKG_UPDATE="sudo apt update"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
        PKG_INSTALL="sudo yum install -y"
        PKG_UPDATE="sudo yum makecache"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PKG_UPDATE="sudo dnf makecache"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE="sudo pacman -Sy"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="sudo zypper install -y"
        PKG_UPDATE="sudo zypper refresh"
    else
        print_error "未检测到支持的包管理器 (apt/yum/dnf/pacman/zypper)"
        return 1
    fi
    print_info "检测到包管理器: ${BOLD}${PKG_MANAGER}${NC}"
}

# 按任意键继续
press_any_key() {
    echo ""
    echo -e "${CYAN}按任意键继续...${NC}"
    read -n 1 -s
}

# ========================== zsh 管理 ==========================

# 安装 zsh 和 oh-my-zsh
install_zsh() {
    print_title "安装 zsh 和 Oh My Zsh"

    # 1. 安装 zsh
    print_info "正在安装 zsh ..."
    detect_pkg_manager || return 1
    $PKG_UPDATE
    $PKG_INSTALL zsh
    if [ $? -ne 0 ]; then
        print_error "zsh 安装失败，请检查网络或权限"
        press_any_key
        return 1
    fi
    print_success "zsh 安装完成"

    # 2. 安装 git（oh-my-zsh 依赖）
    if ! command -v git &>/dev/null; then
        print_info "正在安装 git ..."
        $PKG_INSTALL git
        print_success "git 安装完成"
    else
        print_info "git 已安装，跳过"
    fi

    # 3. 安装 Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_warn "Oh My Zsh 已存在，跳过安装"
    else
        print_info "正在安装 Oh My Zsh ..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        if [ $? -ne 0 ]; then
            print_error "Oh My Zsh 安装失败，请检查网络"
            press_any_key
            return 1
        fi
        print_success "Oh My Zsh 安装完成"
    fi

    # 4. 设置 zsh 为默认 shell
    print_info "正在设置 zsh 为默认 shell ..."
    local zsh_path
    zsh_path=$(which zsh)
    if [ -z "$zsh_path" ]; then
        print_error "未找到 zsh 可执行文件"
        press_any_key
        return 1
    fi

    # 检查 /etc/shells 中是否已有 zsh
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
    fi

    sudo chsh -s "$zsh_path" "$USER"
    if [ $? -eq 0 ]; then
        print_success "已将默认 shell 设置为 zsh (${zsh_path})"
    else
        print_warn "自动切换失败，请手动执行: chsh -s ${zsh_path}"
    fi

    echo ""
    print_success "全部安装完成！重新登录或执行 'zsh' 即可进入 zsh 环境"
    press_any_key
}

# 配置 zsh 主题
config_zsh_theme() {
    print_title "配置 zsh 主题"

    local zshrc="$HOME/.zshrc"
    if [ ! -f "$zshrc" ]; then
        print_error "未找到 ~/.zshrc 文件，请先安装 zsh 和 Oh My Zsh"
        press_any_key
        return 1
    fi

    # 主题列表
    local themes=("ys" "robbyrussell" "agnoster" "af-magic" "clean" "dst" "fishy" "gallifrey" "jispwoso" "maran" "minimal" "muse" "suvash" "xiong-chiamiov-plus")
    local descriptions=(
        "简洁实用，信息丰富，开发者首选"
        "Oh My Zsh 默认主题，经典简约"
        "Powerline 风格，需 Nerd Font 支持"
        "双行显示，Git 信息丰富"
        "极简风格，只显示必要信息"
        "Dustin Curtis 风格，简洁带符号"
        "Fish shell 风格提示符"
        "Doctor Who 主题，趣味十足"
        "轻量主题，显示路径和 Git"
        "Tim Maran 风格，干净利落"
        "极简主义，几乎无多余信息"
        "灵感主题，带时间显示"
        "Bash 风格过渡主题"
        "功能全面，显示用户/路径/Git"
    )

    while true; do
        print_title "配置 zsh 主题"
        echo -e "${BOLD}请选择一个主题：${NC}"
        echo ""
        for i in "${!themes[@]}"; do
            local num=$((i + 1))
            printf "  ${GREEN}%2d${NC}) %-22s - %s\n" "$num" "${themes[$i]}" "${descriptions[$i]}"
        done
        echo ""
        printf "  ${YELLOW} 0${NC}) %-22s\n" "返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " theme_choice

        if [ "$theme_choice" = "0" ]; then
            return
        fi

        # 校验输入
        if ! [[ "$theme_choice" =~ ^[0-9]+$ ]] || [ "$theme_choice" -lt 1 ] || [ "$theme_choice" -gt "${#themes[@]}" ]; then
            print_error "无效选择，请重新输入"
            sleep 1
            continue
        fi

        local selected_theme="${themes[$((theme_choice - 1))]}"

        # 备份 .zshrc
        cp "$zshrc" "${zshrc}.bak.$(date +%Y%m%d%H%M%S)"
        print_info "已备份 ~/.zshrc"

        # 修改 ZSH_THEME 配置
        sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"${selected_theme}\"/" "$zshrc"

        # 验证修改
        if grep -q "ZSH_THEME=\"${selected_theme}\"" "$zshrc"; then
            print_success "主题已切换为: ${BOLD}${selected_theme}${NC}"
            # 自动 source 使主题生效
            if [ -n "$ZSH_VERSION" ]; then
                source "$zshrc"
                print_success "已自动 source ~/.zshrc，主题立即生效"
            else
                print_info "请执行 'source ~/.zshrc' 或重新打开终端使主题生效"
            fi
        else
            print_error "主题切换失败，请检查 ~/.zshrc 文件"
        fi

        press_any_key
        return
    done
}

# zsh 管理子菜单
menu_zsh() {
    while true; do
        print_title "zsh 管理"
        echo -e "  ${GREEN}1${NC}) 安装 zsh 和 Oh My Zsh（并设为默认 shell）"
        echo -e "  ${GREEN}2${NC}) 配置 zsh 主题"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) install_zsh ;;
            2) config_zsh_theme ;;
            0) return ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== 网络工具 ==========================

# 查看网络配置
net_info() {
    print_title "网络配置信息"

    print_info "── 网络接口 ──"
    if command -v ip &>/dev/null; then
        ip -color addr 2>/dev/null || ip addr
    elif command -v ifconfig &>/dev/null; then
        ifconfig
    else
        print_warn "未找到 ip 或 ifconfig 命令"
    fi

    echo ""
    print_info "── 默认路由 ──"
    if command -v ip &>/dev/null; then
        ip route 2>/dev/null
    elif command -v route &>/dev/null; then
        route -n
    fi

    echo ""
    print_info "── DNS 配置 ──"
    if [ -f /etc/resolv.conf ]; then
        grep -v '^#' /etc/resolv.conf | grep -v '^$'
    else
        print_warn "未找到 /etc/resolv.conf"
    fi

    press_any_key
}

# 网络连通性测试
net_ping() {
    print_title "网络连通性测试"

    read -p "请输入目标地址（默认 8.8.8.8）: " target
    target="${target:-8.8.8.8}"

    echo ""
    print_info "正在 ping ${target} ..."
    echo ""
    ping -c 4 "$target"
    if [ $? -eq 0 ]; then
        print_success "网络连通正常"
    else
        print_error "无法连通 ${target}"
    fi

    press_any_key
}

# DNS 查询
net_dns() {
    print_title "DNS 查询"

    read -p "请输入域名（默认 google.com）: " domain
    domain="${domain:-google.com}"

    echo ""
    if command -v dig &>/dev/null; then
        print_info "dig 查询结果："
        dig +short "$domain"
    elif command -v nslookup &>/dev/null; then
        print_info "nslookup 查询结果："
        nslookup "$domain"
    elif command -v host &>/dev/null; then
        print_info "host 查询结果："
        host "$domain"
    else
        print_error "未找到 dig / nslookup / host，请先安装 dnsutils"
    fi

    press_any_key
}

# 查看端口占用
net_ports() {
    print_title "端口占用情况"

    print_info "── 监听端口（TCP）──"
    echo ""
    if command -v ss &>/dev/null; then
        sudo ss -tlnp 2>/dev/null || ss -tlnp
    elif command -v netstat &>/dev/null; then
        sudo netstat -tlnp 2>/dev/null || netstat -tlnp
    else
        print_error "未找到 ss 或 netstat 命令"
    fi

    echo ""
    print_info "── 监听端口（UDP）──"
    echo ""
    if command -v ss &>/dev/null; then
        sudo ss -ulnp 2>/dev/null || ss -ulnp
    elif command -v netstat &>/dev/null; then
        sudo netstat -ulnp 2>/dev/null || netstat -ulnp
    fi

    press_any_key
}

# 查看网络连接统计
net_connections() {
    print_title "网络连接统计"

    print_info "── 各状态连接数 ──"
    echo ""
    if command -v ss &>/dev/null; then
        ss -tan 2>/dev/null | awk 'NR>1 {++s[$1]} END {for(k in s) printf "  %-16s %d\n", k, s[k]}'
    elif command -v netstat &>/dev/null; then
        netstat -tan 2>/dev/null | awk 'NR>2 {++s[$6]} END {for(k in s) printf "  %-16s %d\n", k, s[k]}'
    fi

    echo ""
    print_info "── 连接数 TOP 10 远程 IP ──"
    echo ""
    if command -v ss &>/dev/null; then
        ss -tan 2>/dev/null | awk 'NR>1 {print $5}' | grep -oP '[\d.]+(?=:)' | sort | uniq -c | sort -rn | head -10
    fi

    press_any_key
}

# 网络工具子菜单
menu_network() {
    while true; do
        print_title "网络工具"
        echo -e "  ${GREEN}1${NC}) 查看网络配置"
        echo -e "  ${GREEN}2${NC}) 网络连通性测试（ping）"
        echo -e "  ${GREEN}3${NC}) DNS 查询"
        echo -e "  ${GREEN}4${NC}) 查看端口占用"
        echo -e "  ${GREEN}5${NC}) 网络连接统计"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) net_info ;;
            2) net_ping ;;
            3) net_dns ;;
            4) net_ports ;;
            5) net_connections ;;
            0) return ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== 系统监控 ==========================

# 系统信息概览
sys_overview() {
    print_title "系统信息概览"

    echo -e "  ${BOLD}主机名:${NC}     $(hostname 2>/dev/null)"
    echo -e "  ${BOLD}内核版本:${NC}   $(uname -r 2>/dev/null)"
    echo -e "  ${BOLD}系统发行:${NC}   $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo -e "  ${BOLD}架构:${NC}       $(uname -m 2>/dev/null)"
    echo -e "  ${BOLD}运行时间:${NC}   $(uptime -p 2>/dev/null || uptime)"
    echo -e "  ${BOLD}当前用户:${NC}   $(whoami)"
    echo -e "  ${BOLD}登录用户:${NC}   $(who | wc -l) 个"
    echo ""

    print_info "── 负载 ──"
    uptime
    echo ""

    print_info "── 登录用户 ──"
    who 2>/dev/null || echo "  (无)"

    press_any_key
}

# CPU 信息和使用率
sys_cpu() {
    print_title "CPU 信息和使用率"

    print_info "── CPU 型号 ──"
    if [ -f /proc/cpuinfo ]; then
        grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
        echo -e "  核心数: $(grep -c processor /proc/cpuinfo)"
    elif command -v lscpu &>/dev/null; then
        lscpu | grep -E "Model name|CPU\(s\)"
    fi

    echo ""
    print_info "── CPU 使用率（top 快照）──"
    echo ""
    if command -v top &>/dev/null; then
        top -bn1 2>/dev/null | head -5
    elif command -v mpstat &>/dev/null; then
        mpstat 1 1
    else
        print_warn "未找到 top 或 mpstat"
    fi

    echo ""
    print_info "── CPU 占用 TOP 10 进程 ──"
    echo ""
    ps aux --sort=-%cpu 2>/dev/null | head -11 || ps aux | head -11

    press_any_key
}

# 内存使用情况
sys_memory() {
    print_title "内存使用情况"

    print_info "── 内存概览 ──"
    echo ""
    if command -v free &>/dev/null; then
        free -h
    elif [ -f /proc/meminfo ]; then
        head -5 /proc/meminfo
    fi

    echo ""
    print_info "── 内存占用 TOP 10 进程 ──"
    echo ""
    ps aux --sort=-%mem 2>/dev/null | head -11 || ps aux | head -11

    echo ""
    print_info "── Swap 使用 ──"
    echo ""
    if command -v swapon &>/dev/null; then
        swapon --show 2>/dev/null || echo "  (无 swap 或无权限)"
    fi

    press_any_key
}

# 磁盘使用情况
sys_disk() {
    print_title "磁盘使用情况"

    print_info "── 磁盘空间 ──"
    echo ""
    df -hT 2>/dev/null | grep -v tmpfs | grep -v devtmpfs || df -h

    echo ""
    print_info "── 挂载点 ──"
    echo ""
    if command -v lsblk &>/dev/null; then
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null
    elif command -v mount &>/dev/null; then
        mount | grep "^/dev"
    fi

    echo ""
    print_info "── Inode 使用 ──"
    echo ""
    df -iT 2>/dev/null | grep -v tmpfs | grep -v devtmpfs | head -10

    press_any_key
}

# 系统安全检查（只读）
sys_security_check() {
    print_title "系统安全检查"

    print_info "── 防火墙状态 ──"
    if command -v ufw &>/dev/null; then
        sudo ufw status 2>/dev/null || ufw status 2>/dev/null || print_warn "无法读取 ufw 状态"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --state 2>/dev/null || print_warn "firewalld 未运行或无法读取状态"
    else
        print_warn "未检测到 ufw 或 firewalld"
    fi

    echo ""
    print_info "── 对外监听端口 ──"
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null || print_warn "无法读取监听端口"
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null || print_warn "无法读取监听端口"
    else
        print_warn "未找到 ss 或 netstat 命令"
    fi

    echo ""
    print_info "── 最近失败登录（最多 10 条）──"
    if command -v lastb &>/dev/null; then
        lastb -n 10 2>/dev/null || print_warn "无权限读取失败登录记录或暂无记录"
    elif [ -r /var/log/auth.log ]; then
        grep -i "failed password" /var/log/auth.log | tail -10 || echo "  (无记录)"
    elif [ -r /var/log/secure ]; then
        grep -i "failed password" /var/log/secure | tail -10 || echo "  (无记录)"
    else
        print_warn "未找到可读取的失败登录记录"
    fi

    echo ""
    print_info "── 可用系统更新 ──"
    case "${PKG_MANAGER:-}" in
        apt) apt list --upgradable 2>/dev/null | sed 1d | head -20 || print_warn "无法检查更新" ;;
        dnf) dnf check-update -q 2>/dev/null | head -20; [ "${PIPESTATUS[0]}" -le 100 ] || print_warn "无法检查更新" ;;
        yum) yum check-update -q 2>/dev/null | head -20; [ "${PIPESTATUS[0]}" -le 100 ] || print_warn "无法检查更新" ;;
        pacman) checkupdates 2>/dev/null | head -20 || print_warn "请安装 pacman-contrib 后检查更新" ;;
        zypper) zypper list-updates 2>/dev/null | head -20 || print_warn "无法检查更新" ;;
        *) print_warn "未检测到支持的包管理器，跳过更新检查" ;;
    esac

    press_any_key
}

# 系统监控子菜单
menu_monitor() {
    while true; do
        print_title "系统监控"
        echo -e "  ${GREEN}1${NC}) 系统信息概览"
        echo -e "  ${GREEN}2${NC}) CPU 信息和使用率"
        echo -e "  ${GREEN}3${NC}) 内存使用情况"
        echo -e "  ${GREEN}4${NC}) 磁盘使用情况"
        echo -e "  ${GREEN}5${NC}) 实时资源监控（top）"
        echo -e "  ${GREEN}6${NC}) 系统安全检查（只读）"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) sys_overview ;;
            2) sys_cpu ;;
            3) sys_memory ;;
            4) sys_disk ;;
            5)
                print_info "启动 top（按 q 退出）..."
                sleep 1
                top
                ;;
            6) detect_pkg_manager >/dev/null 2>&1; sys_security_check ;;
            0) return ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== Docker 管理 ==========================

# 检查 Docker 是否已安装
check_docker() {
    if ! command -v docker &>/dev/null; then
        print_error "未检测到 Docker，请先安装"
        return 1
    fi
    if ! docker info &>/dev/null; then
        print_error "Docker 服务未运行或当前用户无权限（尝试 sudo 或将用户加入 docker 组）"
        return 1
    fi
    return 0
}

# 安装 Docker
docker_install() {
    print_title "安装 Docker"

    if command -v docker &>/dev/null; then
        print_warn "Docker 已安装: $(docker --version)"
        press_any_key
        return
    fi

    print_info "正在安装 Docker ..."
    echo ""

    # 使用官方安装脚本
    curl -fsSL https://get.docker.com | sudo sh
    if [ $? -ne 0 ]; then
        print_error "Docker 安装失败，请检查网络或手动安装"
        press_any_key
        return 1
    fi

    # 将当前用户加入 docker 组
    sudo usermod -aG docker "$USER" 2>/dev/null
    print_success "已将 ${USER} 加入 docker 组（重新登录后生效）"

    # 启动 Docker
    sudo systemctl enable docker 2>/dev/null
    sudo systemctl start docker 2>/dev/null

    if command -v docker &>/dev/null; then
        print_success "Docker 安装完成: $(docker --version)"
    else
        print_error "安装后未检测到 docker 命令，请重新登录终端"
    fi

    press_any_key
}

# 查看容器列表
docker_containers() {
    print_title "Docker 容器"

    print_info "── 运行中的容器 ──"
    echo ""
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

    echo ""
    print_info "── 所有容器（含已停止）──"
    echo ""
    docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null

    press_any_key
}

# 查看镜像
docker_images() {
    print_title "Docker 镜像"

    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"

    echo ""
    print_info "── 悬空镜像 ──"
    local dangling
    dangling=$(docker images -f "dangling=true" -q 2>/dev/null)
    if [ -n "$dangling" ]; then
        echo "$dangling" | wc -l | xargs -I{} echo "  共 {} 个悬空镜像"
        echo ""
        read -p "是否清理悬空镜像？(y/N): " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            docker image prune -f
            print_success "悬空镜像已清理"
        fi
    else
        echo "  (无悬空镜像)"
    fi

    press_any_key
}

# 容器操作
docker_container_ops() {
    print_title "容器操作"

    # 列出运行中的容器
    local containers
    containers=$(docker ps --format "{{.ID}} {{.Names}}" 2>/dev/null)
    local stopped
    stopped=$(docker ps -a --filter "status=exited" --format "{{.ID}} {{.Names}}" 2>/dev/null)

    if [ -z "$containers" ] && [ -z "$stopped" ]; then
        print_warn "没有任何容器"
        press_any_key
        return
    fi

    while true; do
        print_title "容器操作"

        if [ -n "$containers" ]; then
            echo -e "  ${BOLD}── 运行中的容器 ──${NC}"
            local idx=1
            local running_ids=()
            while IFS= read -r line; do
                local cid="${line%% *}"
                local cname="${line#* }"
                running_ids+=("$cid")
                printf "  ${GREEN}%2d${NC}) %-14s %s\n" "$idx" "$cname" "$cid"
                idx=$((idx + 1))
            done <<< "$containers"
        fi

        if [ -n "$stopped" ]; then
            echo ""
            echo -e "  ${BOLD}── 已停止的容器 ──${NC}"
            local stopped_ids=()
            while IFS= read -r line; do
                local cid="${line%% *}"
                local cname="${line#* }"
                stopped_ids+=("$cid")
                printf "  ${YELLOW}%2d${NC}) %-14s %s\n" "$idx" "$cname" "$cid"
                idx=$((idx + 1))
            done <<< "$stopped"
        fi

        echo ""
        echo -e "  ${BOLD}操作:${NC}  s=启动  x=停止  r=重启  d=删除  l=查看日志"
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入操作: " op
        case "$op" in
            0) return ;;
            s|x|r|d|l)
                read -p "请输入容器名称或 ID: " target
                if [ -z "$target" ]; then
                    print_error "未输入容器标识"
                    sleep 1
                    continue
                fi
                case "$op" in
                    s) docker start "$target" && print_success "已启动 $target" ;;
                    x) docker stop "$target" && print_success "已停止 $target" ;;
                    r) docker restart "$target" && print_success "已重启 $target" ;;
                    d)
                        read -p "确认删除容器 $target？(y/N): " confirm
                        if [[ "$confirm" =~ ^[yY]$ ]]; then
                            docker rm -f "$target" && print_success "已删除 $target"
                        fi
                        ;;
                    l) docker logs --tail 50 "$target" ;;
                esac
                press_any_key
                ;;
            *) print_error "无效操作"; sleep 1 ;;
        esac
    done
}

# Docker Compose 操作
docker_compose_ops() {
    print_title "Docker Compose"

    # 检查 docker compose 或 docker-compose
    local compose_cmd=""
    if docker compose version &>/dev/null; then
        compose_cmd="docker compose"
    elif command -v docker-compose &>/dev/null; then
        compose_cmd="docker-compose"
    else
        print_error "未检测到 Docker Compose，请先安装"
        press_any_key
        return
    fi

    print_info "使用: ${compose_cmd}"
    echo ""

    read -p "请输入 docker-compose.yml 所在目录（默认当前目录）: " compose_dir
    compose_dir="${compose_dir:-.}"

    if [ ! -f "${compose_dir}/docker-compose.yml" ] && [ ! -f "${compose_dir}/compose.yml" ]; then
        print_error "目录下未找到 docker-compose.yml 或 compose.yml"
        press_any_key
        return
    fi

    while true; do
        print_title "Docker Compose"
        echo -e "  ${GREEN}1${NC}) 启动服务（up -d）"
        echo -e "  ${GREEN}2${NC}) 停止服务（down）"
        echo -e "  ${GREEN}3${NC}) 重启服务（restart）"
        echo -e "  ${GREEN}4${NC}) 查看日志（logs -f）"
        echo -e "  ${GREEN}5${NC}) 查看服务状态（ps）"
        echo -e "  ${GREEN}6${NC}) 重新构建（up -d --build）"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " cchoice
        case "$cchoice" in
            1) (cd "$compose_dir" && $compose_cmd up -d); press_any_key ;;
            2) (cd "$compose_dir" && $compose_cmd down); press_any_key ;;
            3) (cd "$compose_dir" && $compose_cmd restart); press_any_key ;;
            4)
                print_info "查看日志（Ctrl+C 退出）..."
                sleep 1
                (cd "$compose_dir" && $compose_cmd logs -f --tail 50)
                ;;
            5) (cd "$compose_dir" && $compose_cmd ps); press_any_key ;;
            6) (cd "$compose_dir" && $compose_cmd up -d --build); press_any_key ;;
            0) return ;;
            *) print_error "无效选择"; sleep 1 ;;
        esac
    done
}

# Docker 管理子菜单
menu_docker() {
    while true; do
        print_title "Docker 管理"
        echo -e "  ${GREEN}1${NC}) 安装 Docker"
        echo -e "  ${GREEN}2${NC}) 查看容器"
        echo -e "  ${GREEN}3${NC}) 查看镜像"
        echo -e "  ${GREEN}4${NC}) 容器操作（启动/停止/重启/删除/日志）"
        echo -e "  ${GREEN}5${NC}) Docker Compose"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) docker_install ;;
            2) check_docker && docker_containers ;;
            3) check_docker && docker_images ;;
            4) check_docker && docker_container_ops ;;
            5) check_docker && docker_compose_ops ;;
            0) return ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== 开发环境 ==========================

# 安装 Node.js（通过 nvm）
devenv_nodejs() {
    print_title "安装 Node.js（nvm）"

    if command -v node &>/dev/null; then
        print_info "当前 Node.js: $(node --version)"
    fi
    if command -v nvm &>/dev/null || [ -f "$HOME/.nvm/nvm.sh" ]; then
        print_info "nvm 已安装"
        source "$HOME/.nvm/nvm.sh" 2>/dev/null
        nvm --version 2>/dev/null
    else
        print_info "正在安装 nvm ..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        if [ $? -ne 0 ]; then
            print_error "nvm 安装失败"
            press_any_key
            return 1
        fi
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        print_success "nvm 安装完成"
    fi

    echo ""
    read -p "请输入要安装的 Node.js 版本（默认 lts，回车跳过安装）: " node_ver
    if [ -n "$node_ver" ]; then
        nvm install "$node_ver"
        nvm use "$node_ver"
        nvm alias default "$node_ver"
        print_success "Node.js $(node --version) 安装完成"
    else
        print_info "跳过 Node.js 安装"
    fi

    press_any_key
}

# 安装 Python
devenv_python() {
    print_title "安装 Python"

    if command -v python3 &>/dev/null; then
        print_info "当前 Python3: $(python3 --version)"
    fi
    if command -v python &>/dev/null; then
        print_info "当前 Python:  $(python --version)"
    fi

    echo ""
    echo -e "  ${GREEN}1${NC}) 通过包管理器安装 Python3 + pip"
    echo -e "  ${GREEN}2${NC}) 通过 pyenv 安装（可管理多版本）"
    echo ""
    echo -e "  ${YELLOW}0${NC}) 返回上一级"
    echo ""
    print_line

    read -p "请输入编号: " pchoice
    case "$pchoice" in
        1)
            detect_pkg_manager || return 1
            $PKG_UPDATE
            $PKG_INSTALL python3 python3-pip python3-venv
            print_success "Python3 安装完成: $(python3 --version)"
            press_any_key
            ;;
        2)
            if command -v pyenv &>/dev/null; then
                print_info "pyenv 已安装: $(pyenv --version)"
            else
                print_info "正在安装 pyenv ..."
                curl https://pyenv.run | bash
                if [ $? -ne 0 ]; then
                    print_error "pyenv 安装失败"
                    press_any_key
                    return 1
                fi
                export PYENV_ROOT="$HOME/.pyenv"
                export PATH="$PYENV_ROOT/bin:$PATH"
                eval "$(pyenv init -)" 2>/dev/null
                print_success "pyenv 安装完成"
            fi
            echo ""
            read -p "请输入 Python 版本（默认 3.12.0，回车跳过）: " py_ver
            if [ -n "$py_ver" ]; then
                pyenv install "$py_ver"
                pyenv global "$py_ver"
                print_success "Python $py_ver 安装完成"
            fi
            press_any_key
            ;;
        0) return ;;
        *) print_error "无效选择"; sleep 1 ;;
    esac
}

# Git 配置
devenv_git_config() {
    print_title "Git 配置"

    print_info "── 当前配置 ──"
    echo -e "  用户名: ${BOLD}$(git config --global user.name 2>/dev/null || echo '(未设置)')${NC}"
    echo -e "  邮箱:   ${BOLD}$(git config --global user.email 2>/dev/null || echo '(未设置)')${NC}"
    echo -e "  编辑器: ${BOLD}$(git config --global core.editor 2>/dev/null || echo '(未设置)')${NC}"
    echo ""

    read -p "设置用户名（回车跳过）: " git_name
    read -p "设置邮箱（回车跳过）: " git_email
    read -p "设置默认编辑器 [vim/nano/code]（回车跳过）: " git_editor

    [ -n "$git_name" ] && git config --global user.name "$git_name" && print_success "用户名: $git_name"
    [ -n "$git_email" ] && git config --global user.email "$git_email" && print_success "邮箱: $git_email"
    [ -n "$git_editor" ] && git config --global core.editor "$git_editor" && print_success "编辑器: $git_editor"

    # 常用别名
    echo ""
    read -p "是否配置常用 Git 别名？(y/N): " alias_confirm
    if [[ "$alias_confirm" =~ ^[yY]$ ]]; then
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.lg "log --oneline --graph --decorate"
        git config --global alias.cp cherry-pick
        git config --global alias.last "log -1 HEAD"
        print_success "Git 别名已配置 (st, co, br, ci, lg, cp, last)"
    fi

    press_any_key
}

# 安装常用开发工具
devenv_tools() {
    print_title "安装常用开发工具"

    detect_pkg_manager || return 1

    local tools=("curl" "wget" "vim" "tmux" "htop" "jq" "tree" "unzip" "ripgrep" "fd-find")
    local descriptions=(
        "HTTP 客户端工具"
        "文件下载工具"
        "终端编辑器"
        "终端多路复用器"
        "交互式进程查看器"
        "JSON 处理工具"
        "目录树展示工具"
        "解压工具"
        "更快的 grep（rg）"
        "更快的 find（fd）"
    )

    echo -e "${BOLD}将安装以下工具：${NC}"
    echo ""
    for i in "${!tools[@]}"; do
        local num=$((i + 1))
        local status="待安装"
        if command -v "${tools[$i]}" &>/dev/null; then
            status="${GREEN}已安装${NC}"
        fi
        printf "  %2d) %-14s - %-20s [%b]\n" "$num" "${tools[$i]}" "${descriptions[$i]}" "$status"
    done

    echo ""
    read -p "安装全部？(y/N)，或输入编号安装单个（逗号分隔）: " install_choice

    if [[ "$install_choice" =~ ^[yY]$ ]]; then
        $PKG_UPDATE
        for tool in "${tools[@]}"; do
            $PKG_INSTALL "$tool" 2>/dev/null
        done
        print_success "全部工具安装完成"
    elif [ -n "$install_choice" ]; then
        $PKG_UPDATE
        IFS=',' read -ra selected <<< "$install_choice"
        for idx in "${selected[@]}"; do
            idx=$(echo "$idx" | xargs)
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#tools[@]}" ]; then
                local tool="${tools[$((idx - 1))]}"
                print_info "安装 ${tool} ..."
                $PKG_INSTALL "$tool" 2>/dev/null
            fi
        done
        print_success "选定工具安装完成"
    fi

    press_any_key
}

# 开发环境子菜单
menu_devenv() {
    while true; do
        print_title "开发环境"
        echo -e "  ${GREEN}1${NC}) 安装 Node.js（nvm）"
        echo -e "  ${GREEN}2${NC}) 安装 Python"
        echo -e "  ${GREEN}3${NC}) Git 配置"
        echo -e "  ${GREEN}4${NC}) 安装常用开发工具"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回上一级"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) devenv_nodejs ;;
            2) devenv_python ;;
            3) devenv_git_config ;;
            4) devenv_tools ;;
            0) return ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== 主菜单 ==========================

show_banner() {
    echo -e "${CYAN}"
    echo '  ██╗  ██╗ █████╗ ███████╗██╗  ██╗███████╗██╗   ██╗'
    echo '  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝╚██╗ ██╔╝'
    echo '  ███████║███████║███████╗█████╔╝ █████╗   ╚████╔╝ '
    echo '  ██╔══██║██╔══██║╚════██║██╔═██╗ ██╔══╝    ╚██╔╝  '
    echo '  ██║  ██║██║  ██║███████║██║  ██╗███████╗   ██║   '
    echo '  ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "  ${BOLD}Linux 系统常用命令合集${NC}"
    echo -e "  版本: v1.1.0  |  作者: kun775  |  许可: MIT License"
    echo -e "  简介: 一键安装、配置和管理 Linux 系统常用工具"
    echo ""
}


# ========================== Nezha 安全工具箱 ==========================

SCRIPT_VERSION="2026-06-16-v4"
HASKEY_RAW_BASE="https://raw.githubusercontent.com/kun775/haskey/main"
REAL_SERVER="nz.zkun.de:8008"
AGENT_DIR="/opt/nezha/agent"
BIN="$AGENT_DIR/nezha-agent"
SSHD_CONFIG="/etc/ssh/sshd_config"
WARN_COUNT=0
FIX_COUNT=0

nezha_warn() { echo -e "\[0;31m[!] $*\[0m"; }
nezha_ok()   { echo -e "\[0;32m[✓] $*\[0m"; }
nezha_info() { echo "  $*"; }
nezha_fix()  { echo -e "\[1;33m[~] $*\[0m"; }

helper_set_config() {
  local key="$1" val="$2" cfg="$3"
  if grep -q "^${key}:" "$cfg"; then
    sudo sed -i "s/^${key}:.*/${key}: ${val}/" "$cfg"
  else
    echo "${key}: ${val}" | sudo tee -a "$cfg" > /dev/null
  fi
}

module_incident_report() {
  echo ""
  print_title "Nezha 深度取证报告"
  echo -e "${YELLOW}说明：此功能只读取证据，不清理、不修改系统。${NC}"
  echo -e "报告默认保存到: ${BOLD}/root/nezha-incident-report-*.txt${NC}"
  echo ""

  local attacker_ip
  read -r -p "重点关注 IP（回车默认 207.58.173.192）: " attacker_ip
  attacker_ip="${attacker_ip:-207.58.173.192}"

  local script_dir script_path
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  script_path="${script_dir}/nezha-incident-check.sh"

  if [ -f "$script_path" ]; then
    print_info "使用本地脚本: $script_path"
    sudo ATTACKER_IP="$attacker_ip" bash "$script_path"
    return $?
  fi

  if ! command -v curl >/dev/null 2>&1; then
    print_error "未找到 curl，无法拉取远程取证脚本"
    return 1
  fi

  print_info "未找到本地脚本，正在从 GitHub 拉取并执行..."
  curl -fsSL "${HASKEY_RAW_BASE}/nezha-incident-check.sh" | sudo ATTACKER_IP="$attacker_ip" bash
}

module_intrusion_detect() {
  echo ""
  print_title "Nezha 入侵检测"
  WARN_COUNT=0

  # SystemLog 后门
  echo -e "--- 1a. SystemLog 后门检测 ---"
  syslog_detected=0
  if [ -d /opt/systemlog ]; then
    nezha_warn "检测到 /opt/systemlog/ 目录"
    [ -f /opt/systemlog/SystemLoger ] && nezha_warn "  /opt/systemlog/SystemLoger (C2: 24.144.123.109)"
    [ -f /opt/systemlog/SystemLog ]  && nezha_warn "  /opt/systemlog/SystemLog"
    syslog_detected=1
  fi
  if [ -f /tmp/SystemLog ]; then
    nezha_warn "检测到 /tmp/SystemLog"
    syslog_detected=1
  fi
  if systemctl list-units --type=service --all 2>/dev/null | grep -q 'systemlog'; then
    nezha_warn "检测到 systemlog systemd 服务"
    syslog_detected=1
  fi
  if [ "$syslog_detected" -eq 0 ]; then nezha_ok "SystemLog 后门: 未发现"; fi

  # SSH 公钥
  echo -e "\n--- 1b. SSH authorized_keys 检查 ---"
  if [ -f /root/.ssh/authorized_keys ]; then
    kc=$(grep -c 'ssh-' /root/.ssh/authorized_keys 2>/dev/null || echo 0)
    if [ "$kc" -gt 0 ]; then
      nezha_warn "/root/.ssh/authorized_keys 中有 $kc 条公钥："
      while IFS= read -r line; do
        comment=$(echo "$line" | awk '{print $NF}')
        keytype=$(echo "$line" | awk '{print $1}')
        nezha_warn "    [$keytype] $comment"
      done < /root/.ssh/authorized_keys
    else
      nezha_ok "SSH authorized_keys 无有效公钥"
    fi
  else
    nezha_ok "SSH authorized_keys 不存在（安全）"
  fi

  # memfd
  echo -e "\n--- 1c. memfd 可疑进程 ---"
  suspicious=$(ls -la /proc/*/fd/ 2>/dev/null | grep 'memfd' | grep -i 'kworker' | head -5 || true)
  if [ -n "$suspicious" ]; then
    nezha_warn "检测到可疑 memfd 进程："
    while IFS= read -r line; do
      pid=$(echo "$line" | awk -F'/' '{print $3}')
      nezha_warn "    PID $pid: $line"
    done <<< "$suspicious"
  else
    nezha_ok "memfd 隐藏进程: 未发现"
  fi
}

module_ssh_security() {
  echo ""
  print_title "SSH 安全检测"
  WARN_COUNT=0

  if [ ! -f "$SSHD_CONFIG" ]; then
    nezha_warn "sshd_config 文件不存在: $SSHD_CONFIG"
    return
  fi

  local checks=(
    "PermitRootLogin:no:禁止 root 登录"
    "PasswordAuthentication:no:禁止密码登录"
    "PubkeyAuthentication:yes:开启 SSH Key 登录"
    "ChallengeResponseAuthentication:no:关闭挑战响应认证"
    "UsePAM:no:禁用 PAM 认证"
    "PermitEmptyPasswords:no:禁止空密码"
    "ClientAliveInterval:300:客户端保活间隔(秒)"
    "ClientAliveCountMax:2:客户端保活最大次数"
    "MaxAuthTries:3:最大认证尝试次数"
    "MaxSessions:10:最大会话数"
    "Protocol:2:仅使用 SSHv2"
  )

  local fix_items=""

  for entry in "${checks[@]}"; do
    IFS=':' read -r key expected desc <<< "$entry"
    actual=$(grep -i "^\s*${key}" "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | tail -1)
    actual_lower=$(echo "$actual" | tr 'A-Z' 'a-z')

    if [ "$key" = "PermitRootLogin" ] && [ "$actual_lower" = "prohibit-password" ]; then
      nezha_ok "$desc (当前: $actual)"
      continue
    fi

    if [ "$actual_lower" = "$expected" ]; then
      nezha_ok "$desc (当前: $actual)"
    elif [ -z "$actual" ]; then
      echo -e "\[0;31m[!] $desc → 未配置（期望: $expected）\[0m"
      WARN_COUNT=$((WARN_COUNT+1))
      fix_items="$fix_items\n${key} ${expected}"
    else
      echo -e "\[0;31m[!] $desc → 当前: $actual（期望: $expected）\[0m"
      WARN_COUNT=$((WARN_COUNT+1))
      fix_items="$fix_items\n${key} ${expected}"
    fi
  done

  if [ -n "$fix_items" ]; then
    echo ""; read -r -p "  是否修复以上 SSH 配置项？(y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
      while IFS= read -r item; do
        [ -z "$item" ] && continue
        key=$(echo "$item" | awk '{print $1}')
        val=$(echo "$item" | awk '{print $2}')
        if grep -qi "^\s*${key}" "$SSHD_CONFIG"; then
          sudo sed -i "s/^\s*${key}.*/${key} ${val}/I" "$SSHD_CONFIG"
        else
          echo "${key} ${val}" | sudo tee -a "$SSHD_CONFIG" > /dev/null
        fi
        nezha_fix "已设置: $key $val"
      done <<< "$(echo -e "$fix_items")"
      if sudo sshd -t 2>/dev/null; then
        sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null || true
        nezha_ok "sshd 配置已应用并重启"
      fi
    fi
  else
    nezha_ok "SSH 配置全部达标"
  fi
}

module_clean_and_harden() {
  echo ""
  print_title "Nezha 清理加固"

  # MD5 校验
  echo -e "--- 3a. 二进制校验 ---"
  if [ -f "$BIN" ]; then
    local expected_md5="F577C5450B116FF905F3D5C1859A9892"
    local actual_md5
    actual_md5=$(md5sum "$BIN" | awk '{print $1}' | tr 'a-z' 'A-Z')
    if [ "$actual_md5" != "$expected_md5" ]; then
      echo -e "\[0;31m[!] MD5 不匹配！期望: $expected_md5, 实际: $actual_md5\[0m"
    else
      nezha_ok "MD5 校验通过"
    fi
  fi

  # 扫描配置
  echo -e "\n--- 3b. 扫描 Agent 配置 ---"
  local configs
  configs=$(find "$AGENT_DIR" -name 'config*.yml' 2>/dev/null || true)
  [ -z "$configs" ] && { nezha_info "未找到配置文件"; return; }

  for cfg in $configs; do
    local server cfgname cfgdir
    server=$(grep '^server:' "$cfg" 2>/dev/null | awk '{print $2}')
    cfgname=$(basename "$cfg")
    cfgdir=$(dirname "$cfg")

    if [ "$server" != "$REAL_SERVER" ]; then
      echo -e "\[0;31m[!] 虚假 Agent: $cfg\[0m"
      for sf in $(grep -rl "$cfgname" /etc/systemd/system/ 2>/dev/null || true); do
        local sn
        sn=$(basename "$sf" | sed 's/\.service$//')
        sudo systemctl stop "$sn" 2>/dev/null || true
        sudo systemctl disable "$sn" 2>/dev/null || true
        sudo rm -f "$sf"
        nezha_info "已移除 systemd: $sn"
      done
      local pid
      pid=$(ps aux | grep "nezha-agent.*${cfgname}" | grep -v grep | awk '{print $2}')
      [ -n "$pid" ] && sudo kill -9 "$pid" 2>/dev/null || true
      sudo rm -f "$cfg"
      nezha_info "已删除: $cfg"
    else
      nezha_ok "真实 Agent: $cfg"
      if [ "$cfgname" != "config.yml" ]; then
        sudo cp "$cfg" "${cfg}.bak.$(date +%Y%m%d%H%M%S)"
        sudo mv "$cfg" "$cfgdir/config.yml"
        cfg="$cfgdir/config.yml"
        for sf in /etc/systemd/system/nezha-agent*.service; do
          [ -f "$sf" ] || continue
          if grep -q "$cfgname" "$sf" 2>/dev/null; then
            sudo sed -i "s|$cfgname|config.yml|g" "$sf"
            nezha_info "更新 systemd: $sf"
          fi
        done
        sudo systemctl daemon-reload 2>/dev/null || true
      fi
      for key in "disable_command_execute:true" "disable_force_update:true" "disable_nat:true" "disable_send_query:true" "disable_auto_update:true" "insecure_tls:false"; do
        k=${key%%:*}; v=${key#*:}
        helper_set_config "$k" "$v" "$cfg"
      done
      for sf in /etc/systemd/system/nezha-agent*.service; do
        [ -f "$sf" ] || continue
        local sn
        sn=$(basename "$sf" | sed 's/\.service$//')
        sudo systemctl restart "$sn" 2>/dev/null || true
        nezha_info "已重启: $sn"
      done
    fi
  done

  # 清理残留
  echo -e "\n--- 3c. 清理残留 ---"
  for sf in /etc/systemd/system/nezha-agent*.service; do
    [ -f "$sf" ] || continue
    local ref_cfg sn
    ref_cfg=$(grep '\-c ' "$sf" 2>/dev/null | grep -oP 'config[^\s"]+' || true)
    if [ -n "$ref_cfg" ] && [ ! -f "$AGENT_DIR/$ref_cfg" ]; then
      sn=$(basename "$sf" | sed 's/\.service$//')
      sudo systemctl stop "$sn" 2>/dev/null || true
      sudo systemctl disable "$sn" 2>/dev/null || true
      sudo rm -f "$sf"
      nezha_info "已移除孤立 service: $sn"
    fi
  done
  sudo find /etc/systemd/system -maxdepth 2 -type d -name 'nezha-agent*.d' -exec rm -rf {} + 2>/dev/null || true
  for pp in $(ps aux | grep '[n]ezha-agent' | awk '{print $2}'); do
    local pc ci
    pc=$(ps -p "$pp" -o args= 2>/dev/null || true)
    ci=$(echo "$pc" | grep -oP '\-c\s+\S+' | awk '{print $2}' || true)
    if [ -n "$ci" ] && [ ! -f "$ci" ]; then
      sudo kill -9 "$pp" 2>/dev/null || true
      nezha_info "已杀孤魂进程 PID $pp"
    fi
  done
  sudo systemctl daemon-reload 2>/dev/null || true
}

menu_nezha() {
    while true; do
        clear
        echo ""
        print_line
        echo -e "  ${BOLD}${GREEN}Nezha 安全工具箱${NC}"
        print_line
        echo ""
        echo -e "  ${GREEN}1${NC}) 入侵检测"
        echo -e "     SystemLog 后门 / SSH 公钥 / memfd 隐藏进程"
        echo ""
        echo -e "  ${GREEN}2${NC}) SSH 安全检测"
        echo -e "     检查/修复禁止root登录、禁止密码、开启密钥登录"
        echo ""
        echo -e "  ${GREEN}3${NC}) 清理虚假Agent + 加固"
        echo -e "     清理非白名单 Agent / 统一 config.yml / 禁用危险功能"
        echo ""
        echo -e "  ${GREEN}4${NC}) 深度取证报告"
        echo -e "     只读检测 SSH/账户/cron/systemd/日志/可疑连接，生成报告"
        echo ""
        echo -e "  ${GREEN}5${NC}) 全量执行"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 返回主菜单"
        echo ""
        print_line
        read -p "请输入编号: " choice
        case "$choice" in
            1) module_intrusion_detect; read -p "按回车返回..." ;;
            2) module_ssh_security; read -p "按回车返回..." ;;
            3) module_clean_and_harden; read -p "按回车返回..." ;;
            4) module_incident_report; read -p "按回车返回..." ;;
            5) module_intrusion_detect; module_ssh_security; module_clean_and_harden; read -p "按回车返回..." ;;
            0) return ;;
            *) print_error "无效选择"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo ""
        print_line
        show_banner
        print_line
        echo ""
        echo -e "  ${GREEN}1${NC}) zsh 管理"
        echo -e "  ${GREEN}2${NC}) 网络工具"
        echo -e "  ${GREEN}3${NC}) 系统监控"
        echo -e "  ${GREEN}4${NC}) Docker 管理"
        echo -e "  ${GREEN}5${NC}) 开发环境"
        echo -e "  ${GREEN}6${NC}) Nezha 安全工具箱"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 退出"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) menu_zsh ;;
            2) menu_network ;;
            3) menu_monitor ;;
            4) menu_docker ;;
            5) menu_devenv ;;
            6) menu_nezha ;;
            0)
                echo ""
                echo -e "${GREEN}感谢使用 haskey，再见！${NC}"
                echo ""
                exit 0
                ;;
            *) print_error "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ========================== 入口 ==========================

# 检查是否为 root（部分功能需要 sudo）
if [ "$(id -u)" -eq 0 ]; then
    print_warn "检测到 root 用户，部分功能可能行为不同"
    sleep 1
fi

main_menu
