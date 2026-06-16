#!/bin/bash
# ============================================================
#  清理虚假哪吒 Agent + 加固安全配置 + 入侵检测
#  真实 server：nz.zkun.de:8008
#  其他 server 一律视为恶意植入，删除
#  所有真实 agent 的 config 统一重命名为 config.yml，
#  并更新 systemd service 指向 config.yml
# ============================================================
# 版本: 2026-06-16-v3
set -e

SCRIPT_VERSION="2026-06-16-v3"
REAL_SERVER="nz.zkun.de:8008"
AGENT_DIR="/opt/nezha/agent"
BIN="$AGENT_DIR/nezha-agent"

# ANSI 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
red()   { echo -e "${RED}$*${NC}"; }
green() { echo -e "${GREEN}$*${NC}"; }
yellow(){ echo -e "${YELLOW}$*${NC}"; }

echo "脚本版本: $SCRIPT_VERSION"
echo ""

# ==========================================
#  阶段 0: 二进制校验（不一致仅警告，不阻断）
# ==========================================
BIN_MD5_EXPECTED="F577C5450B116FF905F3D5C1859A9892"
if [ -f "$BIN" ]; then
  actual=$(md5sum "$BIN" | awk '{print $1}' | tr 'a-z' 'A-Z')
  if [ "$actual" != "$BIN_MD5_EXPECTED" ]; then
    red "=========================================="
    red " 安全警告：nezha-agent 二进制校验不匹配！"
    red " 期望: $BIN_MD5_EXPECTED"
    red " 实际: $actual"
    red " 文件可能已被篡改（如为 ARM 架构则正常）"
    red " 脚本继续执行，请留意以上异常"
    red "=========================================="
  else
    green "  nezha-agent 二进制 MD5 校验通过"
  fi
fi
echo ""

# ==========================================
#  阶段 1: 入侵检测（非破坏性）
# ==========================================
echo "=========================================="
echo " 阶段 1: 入侵检测..."
echo "=========================================="

# ---- 1a: SystemLog 后门 ----
syslog_detected=0
if [ -f /opt/systemlog/SystemLoger ] || [ -f /opt/systemlog/SystemLog ] || [ -d /opt/systemlog ]; then
  red "[!] 检测到 SystemLog 后门痕迹！"
  [ -d /opt/systemlog ] && red "    /opt/systemlog/ 目录存在"
  [ -f /opt/systemlog/SystemLoger ] && red "    /opt/systemlog/SystemLoger (C2: 24.144.123.109)"
  [ -f /opt/systemlog/SystemLog ] && red "    /opt/systemlog/SystemLog"
  syslog_detected=1
else
  green "  ✅ SystemLog 后门: 未发现"
fi

# ---- 1b: /tmp/SystemLog ----
if [ -f /tmp/SystemLog ]; then
  red "[!] 检测到 /tmp/SystemLog (可疑文件)"
  syslog_detected=1
fi

# ---- 1c: systemlog systemd service ----
if systemctl list-units --type=service --all 2>/dev/null | grep -q 'systemlog'; then
  red "[!] 检测到 systemlog systemd 服务"
  systemctl status systemlog --no-pager 2>/dev/null | grep -E 'ExecStart|Active' | head -3 | while read -r line; do
    red "    $line"
  done
  syslog_detected=1
fi

# ---- 1d: SSH authorized_keys 检查 ----
if [ -f /root/.ssh/authorized_keys ]; then
  key_count=$(grep -c 'ssh-' /root/.ssh/authorized_keys 2>/dev/null || echo 0)
  if [ "$key_count" -gt 0 ]; then
    red "[!] /root/.ssh/authorized_keys 中存在 $key_count 条公钥！"
    while IFS= read -r line; do
      comment=$(echo "$line" | awk '{print $NF}')
      keytype=$(echo "$line" | awk '{print $1}')
      red "    [$keytype] $comment"
    done < /root/.ssh/authorized_keys
  fi
else
  green "  ✅ SSH authorized_keys: 无（安全）"
fi

# ---- 1e: memfd 可疑进程 ----
memfd_kworker=$(ls -la /proc/*/fd/ 2>/dev/null | grep 'memfd' | grep -i 'kworker' || true)
if [ -n "$memfd_kworker" ]; then
  red "[!] 检测到伪装为 kworker 的 memfd 进程！"
  echo "$memfd_kworker" | while read -r line; do
    pid=$(echo "$line" | awk -F'/' '{print $3}')
    red "    PID $pid: $line"
  done
fi

if [ "$syslog_detected" -eq 1 ]; then
  echo ""
  yellow "  ⚠️  建议手动清理后门："
  yellow "     systemctl stop systemlog"
  yellow "     systemctl disable systemlog"
  yellow "     rm -rf /opt/systemlog /tmp/SystemLog"
  yellow "     rm -f /etc/systemd/system/systemlog*"
  yellow "     rm -f /root/.ssh/authorized_keys  # 并更换 SSH 密码"
fi
echo ""

# ==========================================
#  阶段 2: 辅助函数
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
#  阶段 3: 扫描所有 nezha 配置
# ==========================================
echo "=========================================="
echo " 阶段 3: 扫描所有 Nezha Agent 配置..."
echo "=========================================="

configs=$(find "$AGENT_DIR" -name 'config*.yml' 2>/dev/null || true)

if [ -z "$configs" ]; then
  echo "  未找到任何配置文件"
else
  echo "  找到以下配置文件："
  for cfg in $configs; do
    server=$(grep '^server:' "$cfg" 2>/dev/null | awk '{print $2}')
    echo "    $cfg -> server = $server"
  done
fi

echo ""

# ==========================================
#  阶段 4: 每个 config 单独处理
# ==========================================
for cfg in $configs; do
  server=$(grep '^server:' "$cfg" 2>/dev/null | awk '{print $2}')
  cfgname=$(basename "$cfg")
  cfgdir=$(dirname "$cfg")

  if [ "$server" != "$REAL_SERVER" ]; then
    echo "=========================================="
    echo " 虚假 Agent: $cfg  (server=$server)"
    echo "=========================================="

    svc_files=$(grep -rl "$cfgname" /etc/systemd/system/ 2>/dev/null || true)
    for svc_file in $svc_files; do
      svc_name=$(basename "$svc_file" | sed 's/\.service$//')
      echo "  -> 停止并移除 systemd: $svc_name"
      systemctl stop "$svc_name" 2>/dev/null || true
      systemctl disable "$svc_name" 2>/dev/null || true
      rm -f "$svc_file"
    done

    pid=$(ps aux | grep "nezha-agent.*${cfgname}" | grep -v grep | awk '{print $2}')
    if [ -n "$pid" ]; then
      kill -9 "$pid" 2>/dev/null || true
      echo "  -> 已杀进程 PID: $pid"
    fi

    rm -f "$cfg"
    echo "  -> 已删除: $cfg"
    echo ""

  else
    echo "=========================================="
    echo " 真实 Agent: $cfg"
    echo "=========================================="

    # 统一重命名为 config.yml
    if [ "$cfgname" != "config.yml" ]; then
      echo "  -> 重命名: $cfg -> $cfgdir/config.yml"
      cp "$cfg" "${cfg}.bak.$(date +%Y%m%d%H%M%S)"
      mv "$cfg" "$cfgdir/config.yml"
      cfg="$cfgdir/config.yml"

      for svc_file in /etc/systemd/system/nezha-agent*.service; do
        [ -f "$svc_file" ] || continue
        if grep -q "$cfgname" "$svc_file" 2>/dev/null; then
          sed -i "s|$cfgname|config.yml|g" "$svc_file"
          echo "  -> 更新 systemd: $svc_file"
        fi
      done
      systemctl daemon-reload 2>/dev/null || true
    fi

    # 加固：禁用危险功能
    echo "  -> 加固配置..."
    helper_set_config "disable_command_execute" "true" "$cfg"
    helper_set_config "disable_force_update"   "true" "$cfg"
    helper_set_config "disable_nat"            "true" "$cfg"
    helper_set_config "disable_send_query"     "true" "$cfg"
    helper_set_config "disable_auto_update"    "true" "$cfg"
    helper_set_config "insecure_tls"           "false" "$cfg"
    echo "   加固完成"
    echo ""

    # 重启真实 agent（只匹配 nezha-agent 开头的 unit）
    for svc_file in /etc/systemd/system/nezha-agent*.service; do
      [ -f "$svc_file" ] || continue
      svc_name=$(basename "$svc_file" | sed 's/\.service$//')
      systemctl restart "$svc_name" 2>/dev/null || true
      echo "  -> 已重启: $svc_name"
    done
  fi
done

# ==========================================
#  阶段 5: 清理残留
# ==========================================
echo "=========================================="
echo " 阶段 5: 清理残留..."
echo "=========================================="

# 孤立 service（配置已不存在的）
for svc_file in /etc/systemd/system/nezha-agent*.service; do
  [ -f "$svc_file" ] || continue
  ref_cfg=$(grep '\-c ' "$svc_file" 2>/dev/null | grep -oP 'config[^\s"]+' || true)
  if [ -n "$ref_cfg" ] && [ ! -f "$AGENT_DIR/$ref_cfg" ]; then
    svc_name=$(basename "$svc_file" | sed 's/\.service$//')
    echo "  -> 孤立 service: $svc_name (配置已不存在)"
    systemctl stop "$svc_name" 2>/dev/null || true
    systemctl disable "$svc_name" 2>/dev/null || true
    rm -f "$svc_file"
  fi
done

# 残留 drop-in
find /etc/systemd/system -maxdepth 2 -type d -name 'nezha-agent*.d' -exec rm -rf {} + 2>/dev/null || true

# 孤魂进程
for proc_pid in $(ps aux | grep '[n]ezha-agent' | awk '{print $2}'); do
  proc_cmd=$(ps -p "$proc_pid" -o args= 2>/dev/null || true)
  cfg_in_use=$(echo "$proc_cmd" | grep -oP '\-c\s+\S+' | awk '{print $2}' || true)
  if [ -n "$cfg_in_use" ] && [ ! -f "$cfg_in_use" ]; then
    echo "  -> 孤魂进程 PID $proc_pid (配置 $cfg_in_use 已不存在)"
    kill -9 "$proc_pid" 2>/dev/null || true
  fi
done

systemctl daemon-reload 2>/dev/null || true

# ==========================================
#  最终状态
# ==========================================
echo ""
echo "=========================================="
echo " 清理与加固完成！"
echo "=========================================="
echo ""
echo "现存活 nezha:"
systemctl list-units --type=service --all 2>/dev/null | grep nezha || echo "  (无)"
echo ""
echo "存活进程:"
ps aux | grep '[n]ezha' | awk '{print $2, $NF}' || echo "  (无)"
echo ""
echo "配置文件:"
find "$AGENT_DIR" -name 'config*.yml' 2>/dev/null | while read -r f; do
  srv=$(grep '^server:' "$f" | awk '{print $2}')
  echo "  $f -> server: $srv"
done

# 确保退出码为 0
exit 0
