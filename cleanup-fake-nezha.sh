#!/bin/bash
# ============================================================
#  清理虚假哪吒 Agent + 加固安全配置
#  真实 server：nz.zkun.de:8008
#  其他 server 一律视为恶意植入，删除
#  所有真实 agent 的 config 统一重命名为 config.yml，
#  并更新 systemd service 指向 config.yml
# ============================================================
set -e

REAL_SERVER="nz.zkun.de:8008"
AGENT_DIR="/opt/nezha/agent"
BIN="$AGENT_DIR/nezha-agent"

# MD5 校验（期望值全大写）
BIN_MD5_EXPECTED="F577C5450B116FF905F3D5C1859A9892"
if [ -f "$BIN" ]; then
  actual=$(md5sum "$BIN" | awk '{print $1}' | tr 'a-z' 'A-Z')
  if [ "$actual" != "$BIN_MD5_EXPECTED" ]; then
    echo "=========================================="
    echo " 安全警告：nezha-agent 二进制校验不匹配！"
    echo " 期望: $BIN_MD5_EXPECTED"
    echo " 实际: $actual"
    echo " 文件可能已被篡改，脚本终止不执行任何操作"
    echo "=========================================="
    exit 1
  else
    echo "  nezha-agent 二进制 MD5 校验通过"
  fi
fi
echo ""

helper_set_config() {
  local key="$1" val="$2" cfg="$3"
  if grep -q "^${key}:" "$cfg"; then
    sed -i "s/^${key}:.*/${key}: ${val}/" "$cfg"
  else
    echo "${key}: ${val}" >> "$cfg"
  fi
}

# ---- 步骤 1: 查找所有 nezha 配置 ----
echo "=========================================="
echo " 步骤 1: 扫描所有 Nezha Agent 配置..."
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

# ---- 步骤 2: 每个 config 单独处理 ----
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

# ---- 步骤 3: 清理残留 ----
echo "=========================================="
echo " 步骤 3: 清理残留..."
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

# ---- 最终状态 ----
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
