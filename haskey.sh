#!/bin/bash

###############################################################################
# haskey.sh — Linux 系统常用命令合集
# 功能：快速安装、配置和显示 Linux 系统常用工具
# 作者：kun775
# 版本：v1.0.0
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
            print_info "执行 'source ~/.zshrc' 或重新打开终端使主题生效"
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

# ========================== 主菜单 ==========================

show_banner() {
    echo -e "${CYAN}"
    echo "  ╦ ╦╔═╗╔═╗╦╔═╔═╗╦ ╦"
    echo "  ╠═╣╠═╣╚═╗╠╩╗║╣ ╚╦╝"
    echo "  ╩ ╩╩ ╩╚═╝╩ ╩╚═╝ ╩ "
    echo -e "${NC}"
    echo -e "  ${BOLD}Linux 系统常用命令合集${NC}"
    echo -e "  版本: v1.0.0"
    echo -e "  作者: kun775"
    echo -e "  许可: MIT License"
    echo -e "  简介: 一键安装、配置和管理 Linux 系统常用工具"
    echo ""
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
        echo -e "  ${GREEN}2${NC}) 网络工具（待开发）"
        echo -e "  ${GREEN}3${NC}) 系统监控（待开发）"
        echo -e "  ${GREEN}4${NC}) Docker 管理（待开发）"
        echo -e "  ${GREEN}5${NC}) 开发环境（待开发）"
        echo ""
        echo -e "  ${YELLOW}0${NC}) 退出"
        echo ""
        print_line

        read -p "请输入编号: " choice
        case "$choice" in
            1) menu_zsh ;;
            2) print_warn "功能开发中，敬请期待"; sleep 1 ;;
            3) print_warn "功能开发中，敬请期待"; sleep 1 ;;
            4) print_warn "功能开发中，敬请期待"; sleep 1 ;;
            5) print_warn "功能开发中，敬请期待"; sleep 1 ;;
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
