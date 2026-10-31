#!/system/bin/sh
# BBR/CUBIC 运行时切换（需 root）
# 用法:
#   bbr-switch.sh auto    按默认路由接口自动选：wlan* -> bbr，rmnet*/ccmni* -> cubic
#   bbr-switch.sh bbr     强制 BBR（适合 Wi-Fi 高带宽）
#   bbr-switch.sh cubic   强制 CUBIC（适合移动数据）
MODE="${1:-auto}"
if [ "$MODE" = "auto" ]; then
  IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  case "$IFACE" in
    wlan*) MODE=bbr ;;
    *)     MODE=cubic ;;
  esac
fi
echo "iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}') mode=$MODE"
echo "$MODE" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || \
  sysctl -w net.ipv4.tcp_congestion_control="$MODE"
cat /proc/sys/net/ipv4/tcp_congestion_control
