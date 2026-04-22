#!/bin/bash

# =================================================================
# 脚本名称: 宝塔面板通用守护脚本 (客户定制专业版)
# 功能描述: 自动检测面板存活，支持连续检测机制，防止面板假死
# 业务联系: Telegram @hjaxng
# =================================================================

# --- 1. 配置区域 ---
BT_PORT=$([ -f /www/server/panel/data/port.pl ] && cat /www/server/panel/data/port.pl || echo "8888")
LOG_PATH="/var/log/bt_monitor.log"
MONITOR_PATH="/usr/local/bin/bt_monitor_core.sh"

# --- 2. 颜色定义 ---
INFO='\033[0;36m'
SUCCESS='\033[0;32m'
WARN='\033[1;33m'
ERROR='\033[0;31m'
CONTACT='\033[1;35m' # 紫色高亮
NC='\033[0m'

# --- 3. 欢迎界面 (优雅的业务展示) ---
show_welcome() {
    echo -e "${INFO}====================================================${NC}"
    echo -e "         ${SUCCESS}宝塔面板自动守护系统 - 稳定增强版${NC}"
    echo -e "  服务支持: ${CONTACT}Telegram @hjaxng${NC}"
    echo -e "  提示: 本脚本由作者长期维护，为您提供更稳定的服务器环境"
    echo -e "${INFO}====================================================${NC}"
}

# --- 4. 核心逻辑写入 ---
write_core_logic() {
    cat > "$MONITOR_PATH" << 'EOF'
#!/bin/bash
BT_PORT=$([ -f /www/server/panel/data/port.pl ] && cat /www/server/panel/data/port.pl || echo "8888")
MAX_RETRIES=3
RETRY_INTERVAL=5
LOG_PATH="/var/log/bt_monitor.log"

check_panel() {
    local code=$(curl -I -m 5 -o /dev/null -s -w "%{http_code}" "http://127.0.0.1:$BT_PORT")
    if [ "$code" = "000" ]; then
        code=$(curl -I -m 5 -o /dev/null -s -w "%{http_code}" -k "https://127.0.0.1:$BT_PORT")
    fi
    [[ "$code" != "000" ]] && return 0 || return 1
}

FAIL_COUNT=0
for ((i=1; i<=MAX_RETRIES; i++)); do
    if check_panel; then exit 0; else
        ((FAIL_COUNT++))
        [ $i -lt $MAX_RETRIES ] && sleep $RETRY_INTERVAL
    fi
done

if [ $FAIL_COUNT -eq $MAX_RETRIES ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [故障重启] 连续多次检测失败" >> "$LOG_PATH"
    command -v bt >/dev/null 2>&1 && bt 1 > /dev/null 2>&1 || (/etc/init.d/bt restart > /dev/null 2>&1)
    sed -i ':a;$q;N;1001,$D;ba' "$LOG_PATH" 2>/dev/null
fi
EOF
    chmod 700 "$MONITOR_PATH"
}

# --- 5. 功能模块 ---
install() {
    echo -e "${INFO}>> 正在部署守护环境...${NC}"
    write_core_logic
    (crontab -l 2>/dev/null | grep -v "$MONITOR_PATH"; echo "*/5 * * * * $MONITOR_PATH > /dev/null 2>&1") | crontab -
    echo ""
    echo -e "${SUCCESS}[成功] 守护程序已启动！${NC}"
    echo -e "${INFO}日志路径: ${NC}$LOG_PATH"
    echo -e "${INFO}业务咨询: ${CONTACT}Telegram @hjaxng${NC}"
}

uninstall() {
    echo -e "${WARN}>> 正在清理守护环境...${NC}"
    crontab -l 2>/dev/null | grep -v "$MONITOR_PATH" | crontab -
    rm -f "$MONITOR_PATH"
    echo -e "${SUCCESS}[成功] 已彻底移除。如有需要请联系 ${CONTACT}@hjaxng${NC}"
}

show_status() {
    echo -e "${INFO}--- 运行状态 ---${NC}"
    if crontab -l 2>/dev/null | grep -q "$MONITOR_PATH"; then
        echo -e "状态: ${SUCCESS}正常运行中${NC}"
        [ -f "$LOG_PATH" ] && echo -e "日志尾部:\n$(tail -n 3 $LOG_PATH)"
    else
        echo -e "状态: ${ERROR}未安装${NC}"
    fi
    echo -e "维护者: ${CONTACT}@hjaxng${NC}"
}

# --- 6. 执行流 ---
[[ $EUID -ne 0 ]] && echo -e "${ERROR}错误: 请使用 root 权限运行！${NC}" && exit 1

show_welcome

case "$1" in
    install) install ;;
    uninstall) uninstall ;;
    status) show_status ;;
    *)
        echo -e "用法:"
        echo -e "  $0 ${SUCCESS}install${NC}   - 安装/更新监控"
        echo -e "  $0 ${SUCCESS}status${NC}    - 查看状态"
        echo -e "  $0 ${WARN}uninstall${NC} - 卸载监控"
        ;;
esac
