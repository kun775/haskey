#!/bin/bash
# ============================================================
#  Nezha Agent 安全工具箱
#  版本: 2026-06-16-v4
#  仓库: https://github.com/kun775/haskey
# ============================================================
#  功能:
#    1. 入侵检测     - SystemLog 后门 / SSH 公钥 / memfd / SSH 配置
#    2. 清理虚假Agent - 删除非白名单 Nezha Agent
#    3. 加固配置     - MD5 校验 / 禁用危险功能 / SSH 强化
#    4. 全量执行     - 以上全部
#    5. SSH 安全检测  - 检查并修复 SSH 配置
# ============================================================
set -e

SCRIPT_VERSION="2026-06-16-v4"
REAL_SERVER="nz.zkun.de:8008"
AGENT_DIR="/opt/nezha/agent"
BIN="$AGENT_DIR/nezha-agent"
SSHD_CONFIG="/etc/ssh/sshd_config"

# ANSI 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
red()    { echo -e "${RED}$*${NC}"; }
green()  { echo -e "${GREEN}$*${NC}"; }
yellow() { echo -e "${YELLOW}$*${NC}"; }
cyan()   { echo -e "${CYAN}$*${NC}"; }

WARN_COUNT=0
FIX_COUNT=0

warn() { red "[!] $*"; WARN_COUNT=$((WARN_COUNT+1)); }
ok()   { green "[✓] $*"; }
info() { echo "  $*"; }
fix()  { yellow "[~] $*"; FIX_COUNT=$((FIX_COUNT+1)); }

# ==========================================
#  辅助函数
# ==========================================
helper_set_config() {
  local key="$1" val="$2" cfg="$3"
  if grep -q "^${key}:" "$cfg"; then
    sed -i "s/^${key}:.*/${key}: ${val}/" "$cfg"
  else
    echo "${key}: ${val}" >> "$cfg"
  fi
}

# ==========================================
#  模块 1: 入侵检测
# ==========================================
module_intrusion_detect() {
  echo ""
  echo "=========================================="
  echo " 模块 1: 入侵检测"
  echo "=========================================="
  WARN_COUNT=0

  # --- 1a. SystemLog 后门 ---
  echo ""
  echo "--- 1a. SystemLog 后门检测 ---"
  syslog_detected=0
  if [ -d /opt/systemlog ]; then
    warn "检测到 /opt/systemlog/ 目录"
    [ -f /opt/systemlog/SystemLoger ] && warn "  /opt/systemlog/SystemLoger (C2: 24.144.123.109)"
    [ -f /opt/systemlog/SystemLog ]  && warn "  /opt/systemlog/SystemLog"
    syslog_detected=1
  fi
  if [ -f /tmp/SystemLog ]; then
    warn "检测到 /tmp/SystemLog"
    syslog_detected=1
  fi
  if systemctl list-units --type=service --all 2>/dev/null | grep -q 'systemlog'; then
    warn "检测到 systemlog systemd 服务"
    systemctl status systemlog --no-pager 2>/dev/null | grep 'ExecStart' | head -1 | while read -r l; do warn "  $l"; done
    syslog_detected=1
  fi
  if [ "$syslog_detected" -eq 0 ]; then ok "SystemLog 后门: 未发现"; fi

  # --- 1b. SSH 公钥检查 ---
  echo ""
  echo "--- 1b. SSH authorized_keys 检查 ---"
  if [ -f /root/.ssh/authorized_keys ]; then
    kc=$(grep -c 'ssh-' /root/.ssh/authorized_keys 2>/dev/null || echo 0)
    if [ "$kc" -gt 0 ]; then
      warn "/root/.ssh/authorized_keys 中有 $kc 条公钥："
      while IFS= read -r line; do
        comment=$(echo "$line" | awk '{print $NF}')
        keytype=$(echo "$line" | awk '{print $1}')
        warn "    [$keytype] $comment"
      done < /root/.ssh/authorized_keys
    else
      ok "SSH authorized_keys 无有效公钥"
    fi
  else
    ok "SSH authorized_keys 不存在（安全）"
  fi

  # --- 1c. memfd 可疑进程 ---
  echo ""
  echo "--- 1c. memfd 可疑进程 ---"
  suspicious=$(ls -la /proc/*/fd/ 2>/dev/null | grep 'memfd' | grep -iE 'kworker|systemd' | head -5 || true)
  if [ -n "$suspicious" ]; then
    warn "检测到可疑 memfd 进程："
    while IFS= read -r line; do
      pid=$(echo "$line" | awk -F'/' '{print $3}')
      warn "    PID $pid: $line"
    done <<< "$suspicious"
  else
    ok "memfd 隐藏进程: 未发现"
  fi

  echo ""
  if [ "$WARN_COUNT" -gt 0 ]; then
    yellow "  ⚠️  共发现 $WARN_COUNT 个异常，建议手动排查"
  else
    green "  ✅ 入侵检测通过，未发现异常"
  fi
}

# ==========================================
#  模块 2: SSH 安全检测
# ==========================================
module_ssh_security() {
  echo ""
  echo "=========================================="
  echo " 模块 2: SSH 安全检测"
  echo "=========================================="
  WARN_COUNT=0

  if [ ! -f "$SSHD_CONFIG" ]; then
    warn "sshd_config 文件不存在: $SSHD_CONFIG"
    return
  fi

  # SSH 安全基线
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

    # 特殊处理 PermitRootLogin: prohibit-password 也视为通过
    if [ "$key" = "PermitRootLogin" ] && [ "$actual_lower" = "prohibit-password" ]; then
      ok "$desc (当前: $actual)"
      continue
    fi

    if [ "$actual_lower" = "$expected" ]; then
      ok "$desc (当前: $actual)"
    elif [ -z "$actual" ]; then
      warn "  $desc → 未配置（期望: $expected）"
      fix_items="$fix_items\n${key} ${expected}"
    else
      warn "  $desc → 当前: $actual（期望: $expected）"
      fix_items="$fix_items\n${key} ${expected}"
    fi
  done

  # 检查是否允许 AgentForwarding
  agent_fwd=$(grep -i '^\s*AllowAgentForwarding' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | tail -1 | tr 'A-Z' 'a-z')
  if [ "$agent_fwd" = "yes" ]; then
    warn "AllowAgentForwarding 已开启（建议关闭）"
  fi

  echo ""
  if [ -n "$fix_items" ]; then
    echo ""
    yellow "  ⚠️  SSH 配置存在 $WARN_COUNT 项不达标"
    echo ""
    read -r -p "  是否修复以上 SSH 配置项？(y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
      info "已备份: ${SSHD_CONFIG}.bak.*"
      while IFS= read -r item; do
        [ -z "$item" ] && continue
        key=$(echo "$item" | awk '{print $1}')
        val=$(echo "$item" | awk '{print $2}')
        if grep -qi "^\s*${key}" "$SSHD_CONFIG"; then
          sed -i "s/^\s*${key}.*/${key} ${val}/I" "$SSHD_CONFIG"
        else
          echo "${key} ${val}" >> "$SSHD_CONFIG"
        fi
        fix "已设置: $key $val"
      done <<< "$(echo -e "$fix_items")"

      # 单独处理 PermitRootLogin: 允许 prohibit-password
      if grep -qi '^\s*PermitRootLogin' "$SSHD_CONFIG"; then
        sed -i 's/^\s*PermitRootLogin.*/PermitRootLogin no/I' "$SSHD_CONFIG"
      fi

      echo ""
      info "测试 sshd 配置..."
      if sshd -t 2>/dev/null; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        green "  ✅ sshd 配置已应用并重启"
      else
        warn "  sshd 配置测试失败，请检查 ${SSHD_CONFIG}.bak.* 还原"
      fi
    else
      info "跳过修复"
    fi
  else
    green "  ✅ SSH 配置全部达标"
  fi
}

# ==========================================
#  模块 3: 清理虚假 Agent + 加固
# ==========================================
module_clean_and_harden() {
  echo ""
  echo "=========================================="
  echo " 模块 3: 清理虚假 Agent + 加固配置"
  echo "=========================================="

  # --- 3a. MD5 校验 ---
  echo ""
  echo "--- 3a. Nezha Agent 二进制校验 ---"
  if [ -f "$BIN" ]; then
    local expected_md5="F577C5450B116FF905F3D5C1859A9892"
    local actual_md5
    actual_md5=$(md5sum "$BIN" | awk '{print $1}' | tr 'a-z' 'A-Z')
    if [ "$actual_md5" != "$expected_md5" ]; then
      warn "nezha-agent MD5 不匹配！"
      warn "  期望: $expected_md5"
      warn "  实际: $actual_md5"
      warn "  （如为 ARM 架构属正常，脚本继续执行）"
    else
      ok "二进制 MD5 校验通过"
    fi
  else
    warn "二进制文件不存在: $BIN"
  fi

  # --- 3b. 扫描并处理配置 ---
  echo ""
  echo "--- 3b. 扫描 Nezha Agent 配置 ---"

  configs=$(find "$AGENT_DIR" -name 'config*.yml' 2>/dev/null || true)
  if [ -z "$configs" ]; then
    info "未找到任何配置文件"
    return
  fi

  for cfg in $configs; do
    server=$(grep '^server:' "$cfg" 2>/dev/null | awk '{print $2}')
    cfgname=$(basename "$cfg")
    cfgdir=$(dirname "$cfg")

    if [ "$server" != "$REAL_SERVER" ]; then
      warn "虚假 Agent: $cfg (server=$server)"
      for svc_file in $(grep -rl "$cfgname" /etc/systemd/system/ 2>/dev/null || true); do
        svc_name=$(basename "$svc_file" | sed 's/\.service$//')
        systemctl stop "$svc_name" 2>/dev/null || true
        systemctl disable "$svc_name" 2>/dev/null || true
        rm -f "$svc_file"
        info "  已移除 systemd: $svc_name"
      done
      pid=$(ps aux | grep "nezha-agent.*${cfgname}" | grep -v grep | awk '{print $2}')
      [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null || true
      rm -f "$cfg"
      info "  已删除: $cfg"
    else
      green "真实 Agent: $cfg"
      if [ "$cfgname" != "config.yml" ]; then
        info "  重命名: $cfgdir/config.yml"
        cp "$cfg" "${cfg}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$cfg" "$cfgdir/config.yml"
        cfg="$cfgdir/config.yml"
        for sf in /etc/systemd/system/nezha-agent*.service; do
          [ -f "$sf" ] || continue
          grep -q "$cfgname" "$sf" 2>/dev/null && sed -i "s|$cfgname|config.yml|g" "$sf" && info "  更新 systemd: $sf"
        done
        systemctl daemon-reload 2>/dev/null || true
      fi
      info "  加固配置..."
      helper_set_config "disable_command_execute" "true" "$cfg"
      helper_set_config "disable_force_update"   "true" "$cfg"
      helper_set_config "disable_nat"            "true" "$cfg"
      helper_set_config "disable_send_query"     "true" "$cfg"
      helper_set_config "disable_auto_update"    "true" "$cfg"
      helper_set_config "insecure_tls"           "false" "$cfg"
      info "  加固完成"
      for sf in /etc/systemd/system/nezha-agent*.service; do
        [ -f "$sf" ] || continue
        sn=$(basename "$sf" | sed 's/\.service$//')
        systemctl restart "$sn" 2>/dev/null || true
        info "  已重启: $sn"
      done
    fi
  done

  # --- 3c. 清理残留 ---
  echo ""
  echo "--- 3c. 清理残留 ---"
  for sf in /etc/systemd/system/nezha-agent*.service; do
    [ -f "$sf" ] || continue
    ref_cfg=$(grep '\-c ' "$sf" 2>/dev/null | grep -oP 'config[^\s"]+' || true)
    if [ -n "$ref_cfg" ] && [ ! -f "$AGENT_DIR/$ref_cfg" ]; then
      sn=$(basename "$sf" | sed 's/\.service$//')
      systemctl stop "$sn" 2>/dev/null || true
      systemctl disable "$sn" 2>/dev/null || true
      rm -f "$sf"
      info "  已移除孤立 service: $sn"
    fi
  done
  find /etc/systemd/system -maxdepth 2 -type d -name 'nezha-agent*.d' -exec rm -rf {} + 2>/dev/null || true

  for pp in $(ps aux | grep '[n]ezha-agent' | awk '{print $2}'); do
    pc=$(ps -p "$pp" -o args= 2>/dev/null || true)
    ci=$(echo "$pc" | grep -oP '\-c\s+\S+' | awk '{print $2}' || true)
    if [ -n "$ci" ] && [ ! -f "$ci" ]; then
      kill -9 "$pp" 2>/dev/null || true
      info "  已杀孤魂进程 PID $pp"
    fi
  done
  systemctl daemon-reload 2>/dev/null || true
}

# ==========================================
#  最终状态显示
# ==========================================
show_final_status() {
  echo ""
  echo "=========================================="
  echo " 执行完成！"
  echo "=========================================="
  echo ""
  echo "Nezha Agent:"
  systemctl list-units --type=service --all 2>/dev/null | grep nezha || echo "  (无)"
  echo ""
  echo "进程:"
  ps aux | grep '[n]ezha' | awk '{print $2, $NF}' || echo "  (无)"
  echo ""
  echo "配置文件:"
  find "$AGENT_DIR" -name 'config*.yml' 2>/dev/null | while read -r f; do
    echo "  $f -> server: $(grep '^server:' "$f" | awk '{print $2}')"
  done
}

# ==========================================
#  菜单
# ==========================================
show_menu() {
  clear 2>/dev/null || true
  echo ""
  echo "============================================"
  echo "  Nezha Agent 安全工具箱 v${SCRIPT_VERSION}"
  echo "============================================"
  echo ""
  echo "  1)  入侵检测"
  echo "         扫描 SystemLog 后门 / SSH 公钥 / memfd 隐藏进程"
  echo ""
  echo "  2)  SSH 安全检测"
  echo "         检查/修复禁止root登录、禁止密码、开启密钥登录"
  echo ""
  echo "  3)  清理虚假Agent + 加固"
  echo "         清理非白名单 Agent / 统一 config.yml / 禁用危险功能"
  echo ""
  echo "  4)  全量执行"
  echo "         入侵检测 + SSH检测 + 清理加固"
  echo ""
  echo "  0)  退出"
  echo ""
  echo "============================================"
}

# ==========================================
#  主入口
# ==========================================
if [ $# -gt 0 ]; then
  # 命令行参数模式
  case "$1" in
    detect)    module_intrusion_detect; exit 0;;
    ssh)       module_ssh_security; exit 0;;
    clean)     module_clean_and_harden; show_final_status; exit 0;;
    all)       module_intrusion_detect; module_ssh_security; module_clean_and_harden; show_final_status; exit 0;;
    *)         echo "用法: $0 {detect|ssh|clean|all}"; exit 1;;
  esac
fi

# 交互菜单模式
while true; do
  show_menu
  read -r -p "  请选择操作 [0-4]: " choice
  case "$choice" in
    1) module_intrusion_detect
       echo ""; read -r -p "  按回车返回菜单...";;
    2) module_ssh_security
       echo ""; read -r -p "  按回车返回菜单...";;
    3) module_clean_and_harden
       show_final_status
       echo ""; read -r -p "  按回车返回菜单...";;
    4) module_intrusion_detect
       module_ssh_security
       module_clean_and_harden
       show_final_status
       echo ""; read -r -p "  按回车返回菜单...";;
    0) echo "  再见！"; exit 0;;
    *) echo "  无效选项，请重新输入"; sleep 1;;
  esac
done
