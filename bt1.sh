#!/bin/bash

# =================================================================
# 脚本名称: 宝塔面板通用守护脚本 (全系统兼容专业版)
# 功能描述: 自动检测面板存活，支持连续检测机制，防止面板假死
# 安全级别: 高 (无外部依赖，无广告，权限收紧)
# =================================================================

# --- 1. 配置区域 ---
# 自动获取宝塔端口，获取失败则默认为 8888
BT_PORT=$([ -f /www/server/panel/data/port.pl ] && cat /www/server/panel/data/port.pl || echo "8888")
LOG_PATH="/var/log/bt_monitor.log"
MAX_RETRIES=3          # 连续失败多少次才触发重启
RETRY_INTERVAL=5       # 每次重试的间隔秒数
MONITOR_PATH="/usr/local/bin/bt_monitor_core.sh" # 核心逻辑存放路径

# --- 2. 颜色定义 ---
INFO='\033[0;36m'
SUCCESS='\033[0;32m'
WARN='\033[1;33m'
ERROR='\033[0;31m'
NC='\033[0m'

# --- 3. 核心逻辑写入函数 ---
write_core_logic() {
    cat > "$MONITOR_PATH" << 'EOF'
#!/bin/bash
# 核心检测逻辑
BT_PORT=$([ -f /www/server/panel/data/port.pl ] && cat /www/server/panel/data/port.pl || echo "8888")
MAX_RETRIES=3
RETRY_INTERVAL=5
LOG_PATH="/var/log/bt_monitor.log"

check_panel() {
    # 检测 127.0.0.1，支持 http 和 https
    local code=$(curl -I -m 5 -o /dev/null -s -w "%{http_code}" "http://127.0.0.1:$BT_PORT")
    if [ "$code" = "000" ]; then
        code=$(curl -I -m 5 -o /dev/null -s -w "%{http_code}" -k "https://127.0.0.1:$BT_PORT")
    fi
    # 只要能连接上(非000)，不论是200还是401/404都认为面板进程还在
    [[ "$code" != "000" ]] && return 0 || return 1
}

FAIL_COUNT=0
for ((i=1; i<=MAX_RETRIES; i++)); do
    if check_panel; then
        exit 0
    else
        ((FAIL_COUNT++))
        [ $i -lt $MAX_RETRIES ] && sleep $RETRY_INTERVAL
    fi
done

if [ $FAIL_COUNT -eq $MAX_RETRIES ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [致命] 连续 $MAX_RETRIES 次检测失败，重启面板" >> "$LOG_PATH"
    if command -v bt >/dev/null 2>&1; then
        bt 1 > /dev/null 2>&1
    elif [ -f /etc/init.d/bt ]; then
        /etc/init.d/bt restart > /dev/null 2>&1
    fi
    # 日志维护：保留最后1000行
    sed -i ':a;$q;N;1001,$D;ba' "$LOG_PATH" 2>/dev/null
fi
EOF
    chmod 700 "$MONITOR_PATH"
}

# --- 4. 功能函数 ---
install() {
    echo -e "${INFO}>> 正在安装守护程序...${NC}"
    write_core_logic
    # 写入 Crontab (每 5 分钟执行一次)
    (crontab -l 2>/dev/null | grep -v "$MONITOR_PATH"; echo "*/5 * * * * $MONITOR_PATH > /dev/null 2>&1") | crontab -
    echo -e "${SUCCESS}[成功] 守护程序已启动，日志: $LOG_PATH${NC}"
}

uninstall() {
    echo -e "${WARN}>> 正在卸载守护程序...${NC}"
    crontab -l 2>/dev/null | grep -v "$MONITOR_PATH" | crontab -
    rm -f "$MONITOR_PATH"
    echo -e "${SUCCESS}[成功] 守护程序已彻底移除。${NC}"
}

show_status() {
    echo -e "${INFO}--- 运行状态 ---${NC}"
    if crontab -l 2>/dev/null | grep -q "$MONITOR_PATH"; then
        echo -e "状态: ${SUCCESS}监控中${NC}"
        echo -e "频率: 每 5 分钟检测一次"
        [ -f "$LOG_PATH" ] && echo -e "最近日志:\n$(tail -n 3 $LOG_PATH)"
    else
        echo -e "状态: ${ERROR}未安装${NC}"
    fi
}

# --- 5. 主菜单 ---
[[ $EUID -ne 0 ]] && echo -e "${ERROR}错误: 请使用 root 权限运行！${NC}" && exit 1

case "$1" in
    install) install ;;
    uninstall) uninstall ;;
    status) show_status ;;
    *)
        echo -e "${INFO}用法:${NC}"
        echo -e "  $0 install   - 安装/更新监控"
        echo -e "  $0 uninstall - 卸载监控"
        echo -e "  $0 status    - 查看状态"
        ;;
esac
