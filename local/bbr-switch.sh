#!/system/bin/sh
# BBR / CUBIC 运行时切换（需 root）
#
# 注意：net.ipv4.tcp_congestion_control 是【全局】开关，
# 不能做到 Wi-Fi 走 BBR、蜂窝同时走 CUBIC。auto 只是按当前默认路由选一个全局算法。
# 只对新连接生效，已有连接保持原算法。
#
# 用法:
#   bbr-switch.sh auto   # 按默认路由：wlan* -> bbr，rmnet*/ccmni* -> cubic，其它 -> cubic
#   bbr-switch.sh bbr    # 强制 BBR（Wi-Fi 高带宽场景）
#   bbr-switch.sh cubic  # 强制 CUBIC（移动数据推荐）
#
# 自动跟随网络变化：可放进模块 service.sh，配合循环/网络监听调用本脚本 auto。

MODE="${1:-auto}"
CC=/proc/sys/net/ipv4/tcp_congestion_control
AVAIL=/proc/sys/net/ipv4/tcp_available_congestion_control

iface=$(ip route get 8.8.8.8 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n1)
if [ "$MODE" = "auto" ]; then
  case "$iface" in
    wlan*)        MODE=bbr ;;
    rmnet*|ccmni*) MODE=cubic ;;
    *)            MODE=cubic ;;
  esac
fi

if [ ! -r "$CC" ]; then echo "ERROR: $CC 不可读（需要 root）"; exit 1; fi

case " $(cat "$AVAIL" 2>/dev/null) " in
  *" $MODE "*) : ;;
  *) echo "ERROR: $MODE 不在可用列表: $(cat "$AVAIL" 2>/dev/null)"; exit 1 ;;
esac

echo "$MODE" > "$CC" || { echo "ERROR: 写入 $CC 失败"; exit 1; }
cur=$(cat "$CC")
echo "iface=${iface:-unknown} requested=$MODE current=$cur"
[ "$cur" = "$MODE" ] || { echo "WARN: 切换未生效"; exit 1; }
echo "OK（仅对新连接生效）"
