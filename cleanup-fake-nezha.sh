#!/bin/bash
set -e

REAL_SERVER="nz.zkun.de:8008"

echo "🧹 开始清理虚假哪吒 Agent..."

find /opt/nezha -name 'config*.yml' | while read cfg; do
  server=$(grep '^server:' "$cfg" 2>/dev/null | awk '{print $2}')
  echo "  检查: $cfg → server = $server"

  if [ "$server" = "$REAL_SERVER" ]; then
    echo "  ✅ 真实 Agent，跳过"
    continue
  fi

  echo "  ❌ 虚假 Agent 检测到！处理中..."

  # 找出引用此 config 的 systemd service
  svc_file=$(grep -rl "$cfg" /etc/systemd/system/ 2>/dev/null | head -1)
  svc_name=$(basename "$svc_file" 2>/dev/null | sed 's/\.service$//')

  if [ -n "$svc_name" ]; then
    echo "   → 停止并禁用 service: $svc_name"
    systemctl stop "$svc_name" 2>/dev/null || true
    systemctl disable "$svc_name" 2>/dev/null || true
    rm -f "$svc_file"
    echo "   → 已移除 systemd: $svc_file"
  else
    echo "   → 未找到关联的 systemd service"
  fi

  # 杀掉使用此配置的进程
  pid=$(ps aux | grep "nezha-agent.*-c.*${cfg}" | grep -v grep | awk '{print $2}')
  if [ -n "$pid" ]; then
    kill -9 "$pid" 2>/dev/null || true
    echo "   → 已杀进程 PID: $pid"
  fi

  # 删掉虚假的配置文件
  rm -f "$cfg"
  echo "   → 已删除配置: $cfg"
done

# 删除残留的 systemd drop-in
find /etc/systemd/system -type d -name 'nezha-agent*.d' -exec rm -rf {} + 2>/dev/null || true

systemctl daemon-reload
echo ""
echo "✅ 清理完成！"
echo ""
echo "当前系统 nezha 状态："
systemctl list-units --type=service --all 2>/dev/null | grep nezha || echo "  （无存活 nezha agent）"
ps aux | grep '[n]ezha' || echo "  （无存活 nezha 进程）"
