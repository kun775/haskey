#!/usr/bin/env bash
# Nezha incident triage script
# 只读取证：检测哪吒面板相关入侵痕迹、SSH 后门、账户/权限、持久化、日志与可疑连接。

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ALERT_COUNT=0
WARN_COUNT=0
INFO_COUNT=0
HOSTNAME_SAFE=$(hostname 2>/dev/null | tr -cd '[:alnum:]._-' || echo unknown)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="/root/nezha-incident-report-${HOSTNAME_SAFE}-${TIMESTAMP}.txt"
ATTACKER_IP="${ATTACKER_IP:-207.58.173.192}"
NEZHA_DIRS=("/opt/nezha" "/etc/nezha" "/var/lib/nezha")
WEB_LOGS=("/var/log/nginx/access.log" "/var/log/nginx/error.log" "/var/log/apache2/access.log" "/var/log/apache2/error.log" "/var/log/httpd/access_log" "/var/log/httpd/error_log" "/opt/nezha/dashboard/access.log" "/opt/nezha/dashboard/app.log")
AUTH_LOGS=("/var/log/auth.log" "/var/log/auth.log.1" "/var/log/secure" "/var/log/secure.1")

exec > >(tee "$REPORT") 2>&1

color() {
    local code="$1"
    shift
    if [ -t 1 ]; then
        printf "%b%s%b\n" "$code" "$*" "$NC"
    else
        printf "%s\n" "$*"
    fi
}

section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

alert() {
    color "$RED" "[!] $*"
    ALERT_COUNT=$((ALERT_COUNT + 1))
}

warn() {
    color "$YELLOW" "[?] $*"
    WARN_COUNT=$((WARN_COUNT + 1))
}

ok() {
    color "$GREEN" "[√] $*"
}

info() {
    color "$BLUE" "[*] $*"
    INFO_COUNT=$((INFO_COUNT + 1))
}

redact() {
    sed -E \
        -e 's/(Authorization: Bearer )[A-Za-z0-9._~+\/-]+=*/\1<REDACTED>/Ig' \
        -e "s/(token|jwt|secret|password|passwd|pwd)([\"' ]*[:=][\"' ]*)[^ \"',}]+/\\1\\2<REDACTED>/Ig" \
        -e 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<JWT_REDACTED>/g'
}

file_perm() {
    stat -c "%a" "$1" 2>/dev/null || stat -f "%OLp" "$1" 2>/dev/null || echo unknown
}

file_mtime() {
    stat -c "%y" "$1" 2>/dev/null || stat -f "%Sm" "$1" 2>/dev/null || echo unknown
}

have() {
    command -v "$1" >/dev/null 2>&1
}

print_header() {
    echo "哪吒面板入侵痕迹检测报告"
    echo "生成时间: $(date -Is 2>/dev/null || date)"
    echo "主机名: $(hostname 2>/dev/null || echo unknown)"
    echo "内核: $(uname -a 2>/dev/null || echo unknown)"
    echo "当前用户: $(id 2>/dev/null || echo unknown)"
    echo "报告路径: $REPORT"
    echo "重点关注 IP: $ATTACKER_IP"
    echo "模式: 只读检测，不清理、不修改系统"
}

check_root() {
    section "0. 权限与环境"
    if [ "$(id -u 2>/dev/null)" != "0" ]; then
        warn "当前不是 root，部分日志、SSH、cron、systemd 检查可能不完整"
    else
        ok "以 root 权限运行"
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "系统: ${PRETTY_NAME:-unknown}"
    fi

    echo "uptime: $(uptime 2>/dev/null || echo unknown)"
}

check_nezha_config() {
    section "1. 哪吒配置与权限"
    local configs=()
    local path

    for path in \
        /opt/nezha/dashboard/data/config.yaml \
        /opt/nezha/dashboard/data/config.yml \
        /opt/nezha/dashboard/config.yaml \
        /etc/nezha/config.yaml; do
        [ -f "$path" ] && configs+=("$path")
    done

    while IFS= read -r path; do
        [ -n "$path" ] && configs+=("$path")
    done < <(find /opt/nezha /etc/nezha -maxdepth 5 -type f \( -name 'config.yaml' -o -name 'config.yml' \) 2>/dev/null | sort -u)

    if [ "${#configs[@]}" -eq 0 ]; then
        warn "未找到常见哪吒配置文件"
        return
    fi

    printf '%s\n' "${configs[@]}" | sort -u | while IFS= read -r cfg; do
        [ -f "$cfg" ] || continue
        local perms owner mtime
        perms=$(file_perm "$cfg")
        owner=$(stat -c "%U:%G" "$cfg" 2>/dev/null || stat -f "%Su:%Sg" "$cfg" 2>/dev/null || echo unknown)
        mtime=$(file_mtime "$cfg")
        echo "配置文件: $cfg"
        echo "权限/属主/修改时间: $perms / $owner / $mtime"

        case "$perms" in
            600|400|640|440) ok "配置文件权限较收敛" ;;
            unknown) warn "无法读取配置文件权限" ;;
            *) alert "配置文件权限偏宽，可能导致 secret/JWT 泄露；建议收敛到 600 或 640" ;;
        esac

        if grep -Eiq 'jwt|secret|token|password' "$cfg" 2>/dev/null; then
            info "发现敏感配置字段，以下仅显示键名不显示值"
            grep -Ein 'jwt|secret|token|password' "$cfg" 2>/dev/null | sed -E 's/(:[[:space:]]*).*/:\1<REDACTED>/' | head -20
            warn "如确认被入侵，建议重置面板密码、JWT/secret、Agent 密钥并重启服务"
        fi
        echo "----------------------------------------"
    done
}

check_ssh_keys() {
    section "2. SSH 公钥后门"
    local found=0
    local key_file

    while IFS= read -r key_file; do
        [ -f "$key_file" ] || continue
        found=1
        echo "文件: $key_file"
        echo "权限/属主/修改时间: $(file_perm "$key_file") / $(stat -c "%U:%G" "$key_file" 2>/dev/null || echo unknown) / $(file_mtime "$key_file")"

        local key_count
        key_count=$(grep -Ec '^(from=|command=|no-|restrict|ssh-|ecdsa-|sk-|rsa-|ed25519)' "$key_file" 2>/dev/null || echo 0)
        echo "公钥/规则行数: $key_count"

        awk 'NF && $0 !~ /^#/ {print}' "$key_file" 2>/dev/null | while IFS= read -r line; do
            local key_part fingerprint comment options
            if [[ "$line" == ssh-* || "$line" == ecdsa-* || "$line" == sk-* ]]; then
                key_part="$line"
                options=""
            else
                key_part=$(echo "$line" | grep -Eo '(ssh|ecdsa|sk)-[^ ]+ [^ ]+' | head -1)
                options=$(echo "$line" | sed -E 's/(ssh|ecdsa|sk)-[^ ]+ .*$//')
            fi

            fingerprint=$(printf '%s\n' "$key_part" | ssh-keygen -lf /dev/stdin 2>/dev/null | awk '{print $2" "$4}')
            comment=$(printf '%s\n' "$line" | awk '{print $NF}')
            echo "指纹: ${fingerprint:-无法解析} | 备注: ${comment:-无}"
            [ -n "$options" ] && echo "限制/选项: $options"

            if echo "$line" | grep -Eiq 'backdoor|my_access|hacker|root@kali|INaBWgeVj6ZAq9zsuCrIbdZIuctB'; then
                alert "发现可疑 SSH 公钥特征: $key_file"
            fi
        done

        local perms
        perms=$(file_perm "$key_file")
        [ "$perms" = "600" ] || [ "$perms" = "400" ] || warn "authorized_keys 权限不是 600/400: $key_file ($perms)"
        echo "----------------------------------------"
    done < <(find /root /home -path '*/.ssh/authorized_keys' -type f 2>/dev/null | sort)

    [ "$found" -eq 1 ] || ok "未发现 authorized_keys 文件"

    if [ -f /etc/ssh/sshd_config ]; then
        echo "sshd_config 中关键配置:"
        grep -Ein '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AuthorizedKeysFile|AllowUsers|AllowGroups|PermitEmptyPasswords)' /etc/ssh/sshd_config 2>/dev/null || true
    fi
}

check_accounts() {
    section "3. 账户、UID 0 与 sudoers"
    echo "UID 0 账户:"
    awk -F: '$3 == 0 {print $1":"$3":"$6":"$7}' /etc/passwd 2>/dev/null
    local uid0_count
    uid0_count=$(awk -F: '$3 == 0 {count++} END {print count+0}' /etc/passwd 2>/dev/null)
    [ "$uid0_count" -gt 1 ] && alert "发现非 root UID 0 账户，请人工确认"

    echo ""
    echo "可登录 shell 账户:"
    awk -F: '$7 !~ /(nologin|false|sync|shutdown|halt)$/ {print $1":"$3":"$6":"$7}' /etc/passwd 2>/dev/null

    echo ""
    echo "最近修改的账户文件:"
    for file in /etc/passwd /etc/shadow /etc/group /etc/sudoers; do
        [ -e "$file" ] && echo "$file -> $(file_mtime "$file")"
    done

    echo ""
    echo "sudoers.d 文件:"
    find /etc/sudoers.d -type f -maxdepth 1 -print -exec sh -c 'for f; do echo "$f -> $(stat -c "%a %U:%G %y" "$f" 2>/dev/null)"; grep -Ev "^#|^$" "$f" 2>/dev/null | sed -E "s/(ALL=\(ALL(:ALL)?\) NOPASSWD:).*/\1 <COMMANDS>/"; done' sh {} + 2>/dev/null || true
}

check_logins() {
    section "4. SSH 登录与认证失败"
    echo "最近登录记录:"
    last -aiF -n 30 2>/dev/null || last -n 30 2>/dev/null || true

    echo ""
    echo "当前会话:"
    who -a 2>/dev/null || who 2>/dev/null || true

    echo ""
    local total_fail=0
    local log count
    for log in "${AUTH_LOGS[@]}"; do
        [ -f "$log" ] || continue
        count=$(grep -Eci 'Failed password|authentication failure|Invalid user|Connection closed by authenticating user' "$log" 2>/dev/null || echo 0)
        echo "$log 认证失败相关记录: $count"
        total_fail=$((total_fail + count))
        grep -Ei 'Accepted password|Accepted publickey|Failed password|Invalid user|authentication failure' "$log" 2>/dev/null | tail -20 | redact || true
    done

    if have journalctl; then
        echo ""
        echo "journalctl SSH 摘要（最近 24h）:"
        journalctl --since '24 hours ago' -u ssh -u sshd --no-pager 2>/dev/null | grep -Ei 'Accepted|Failed|Invalid|authentication failure' | tail -50 | redact || true
    fi

    [ "$total_fail" -gt 100 ] && alert "认证失败次数较高，可能存在暴力尝试"
}

check_persistence() {
    section "5. 持久化：cron、systemd、启动脚本"

    echo "root crontab:"
    crontab -l 2>/dev/null | redact || echo "无或无权限读取"

    echo ""
    echo "用户 crontab spool:"
    find /var/spool/cron /var/spool/cron/crontabs -type f 2>/dev/null | while IFS= read -r file; do
        echo "--- $file ($(file_mtime "$file"))"
        sed -n '1,80p' "$file" 2>/dev/null | redact
    done

    echo ""
    echo "系统 cron 可疑条目:"
    grep -RInE 'curl|wget|bash -c|/dev/tcp|nc |python|perl|php|base64|chmod|chattr|/tmp|/dev/shm' /etc/cron* 2>/dev/null | redact | head -100 || true

    echo ""
    echo "最近 7 天修改的 systemd unit:"
    find /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system -type f -mtime -7 2>/dev/null | sort | while IFS= read -r unit; do
        echo "$unit -> $(file_mtime "$unit")"
        grep -Ei 'ExecStart|ExecStartPre|WantedBy|curl|wget|/tmp|/dev/shm|bash|python|perl|php|nc ' "$unit" 2>/dev/null | redact | head -20
        echo "----------------------------------------"
    done

    echo "启动脚本/环境后门关键字:"
    grep -RInE 'curl|wget|/dev/tcp|LD_PRELOAD|PROMPT_COMMAND|authorized_keys|bash -i|nc -e|base64' /etc/rc.local /etc/profile /etc/profile.d /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile 2>/dev/null | redact | head -100 || true
}

check_process_network() {
    section "6. 进程、监听端口与外连"
    echo "哪吒相关进程:"
    ps auxww 2>/dev/null | grep -Ei 'nezha|dashboard|agent' | grep -v grep || warn "未发现明显哪吒相关进程"

    echo ""
    echo "可疑目录运行进程:"
    ps auxww 2>/dev/null | grep -E '/tmp|/dev/shm|/var/tmp|\./\.' | grep -v grep | redact || ok "未发现从常见临时目录运行的进程"

    echo ""
    echo "监听端口:"
    if have ss; then
        ss -tulpen 2>/dev/null | redact
    elif have netstat; then
        netstat -tulpen 2>/dev/null | redact
    else
        warn "未找到 ss/netstat"
    fi

    echo ""
    echo "与重点 IP 的连接: $ATTACKER_IP"
    if have ss; then
        ss -antp 2>/dev/null | grep -F "$ATTACKER_IP" | redact || ok "未发现与重点 IP 的当前连接"
    elif have netstat; then
        netstat -antp 2>/dev/null | grep -F "$ATTACKER_IP" | redact || ok "未发现与重点 IP 的当前连接"
    fi

    echo ""
    echo "ESTABLISHED 外连数量:"
    if have ss; then
        ss -ant state established 2>/dev/null | tail -n +2 | wc -l
        ss -antp state established 2>/dev/null | tail -30 | redact || true
    elif have netstat; then
        netstat -antp 2>/dev/null | grep ESTABLISHED | wc -l
        netstat -antp 2>/dev/null | grep ESTABLISHED | tail -30 | redact || true
    fi
}

check_web_logs() {
    section "7. Web/哪吒日志攻击痕迹"
    local any=0
    local log
    for log in "${WEB_LOGS[@]}"; do
        [ -f "$log" ] || continue
        any=1
        echo "日志: $log"
        echo "重点 IP 命中数: $(grep -Fc "$ATTACKER_IP" "$log" 2>/dev/null || echo 0)"
        grep -F "$ATTACKER_IP" "$log" 2>/dev/null | tail -20 | redact || true

        echo "目录穿越/配置读取/API 异常样本:"
        grep -Ei '\.\./|%2e%2e|config\.ya?ml|/api/v1/login|jwt|token|unauthorized|forbidden|401|403' "$log" 2>/dev/null | tail -30 | redact || true

        echo "Top IP:"
        awk '{print $1}' "$log" 2>/dev/null | grep -E '^[0-9a-fA-F:.]+$' | sort | uniq -c | sort -nr | head -10 || true
        echo "----------------------------------------"
    done

    [ "$any" -eq 1 ] || warn "未找到常见 Web/哪吒日志文件"
}

check_recent_files() {
    section "8. 最近修改的敏感文件"
    local dir
    for dir in /root/.ssh /home /opt/nezha /etc/ssh /etc/sudoers.d /etc/systemd/system /tmp /dev/shm /var/tmp; do
        [ -e "$dir" ] || continue
        echo "目录: $dir"
        find "$dir" -xdev -type f -mtime -2 -printf '%TY-%Tm-%Td %TH:%TM %u:%g %m %p\n' 2>/dev/null | sort | tail -80
        echo "----------------------------------------"
    done
}

check_package_changes() {
    section "9. 最近软件安装/变更"
    [ -f /var/log/apt/history.log ] && { echo "APT history:"; tail -80 /var/log/apt/history.log | redact; }
    [ -f /var/log/dpkg.log ] && { echo "DPKG log:"; tail -80 /var/log/dpkg.log | redact; }
    [ -f /var/log/yum.log ] && { echo "YUM log:"; tail -80 /var/log/yum.log | redact; }
    [ -f /var/log/dnf.log ] && { echo "DNF log:"; tail -80 /var/log/dnf.log | redact; }
}

summary() {
    section "总结"
    echo "高危告警: $ALERT_COUNT"
    echo "注意事项: $WARN_COUNT"
    echo "信息提示: $INFO_COUNT"
    echo "报告路径: $REPORT"

    if [ "$ALERT_COUNT" -eq 0 ]; then
        ok "未发现明显高危入侵痕迹，但仍建议结合云厂商登录记录和快照做复核"
    else
        alert "发现高危迹象，请先保全报告和日志，再清理后门/轮换密钥/限制面板访问"
    fi

    echo ""
    echo "建议下一步:"
    echo "1. 保存本报告和 /var/log、哪吒日志、面板配置文件的副本。"
    echo "2. 立即重置哪吒面板密码、JWT/secret、Agent 密钥。"
    echo "3. 人工确认 authorized_keys、sudoers、cron、systemd 中的异常项。"
    echo "4. 限制面板仅允许可信 IP 访问，关闭公网裸露管理面。"
    echo "5. 若发现 UID 0 后门、未知 systemd、反连进程，优先考虑重装系统并恢复可信数据。"
}

main() {
    print_header
    check_root
    check_nezha_config
    check_ssh_keys
    check_accounts
    check_logins
    check_persistence
    check_process_network
    check_web_logs
    check_recent_files
    check_package_changes
    summary
}

main "$@"
