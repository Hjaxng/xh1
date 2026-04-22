#!/bin/bash

# =================================================================
# 脚本名称: 宝塔面板通用守护脚本 (交互菜单定制版)
# 核心逻辑: 连续3次失败判定 + HTTP/HTTPS自适应
# 业务联系: Telegram @hjaxng
# =================================================================

# --- 颜色定义 ---
INFO='\033[0;36m'    # 青色
SUCCESS='\033[0;32m' # 绿色
WORKING='\033[1;33m' # 黄色
ERROR='\033[0;31m'   # 红色
CONTACT='\033[1;35m' # 紫色高亮
NC='\033[0m'         # 重置

# --- 配置路径 ---
MONITOR_PATH="/usr/local/bin/bt_monitor_core.sh"
LOG_PATH="/var/log/bt_monitor.log"

# --- 专属版权与联系方式 ---
show_ad() {
    clear
    echo -e "${CONTACT}====================================================${NC}"
    echo -e "         ${SUCCESS}宝塔面板自动守护系统 - 稳定增强版${NC}"
    echo -e "  业务支持: ${CONTACT}Telegram @hjaxng${NC}"
    echo -e "  温馨提示: 本脚本由作者长期维护，如有需求请直接联系。"
    echo -e "${CONTACT}====================================================${NC}"
}

# --- 核心逻辑写入 (隐藏在后台运行的代码) ---
write_core_script() {
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [致命异常] 连续3次尝试失败，触发重启" >> "$LOG_PATH"
    if command -v bt >/dev/null 2>&1; then
        bt 1 > /dev/null 2>&1
    else
        /etc/init.d/bt restart > /dev/null 2>&1
    fi
    sed -i ':a;$q;N;1001,$D;ba' "$LOG_PATH" 2>/dev/null
fi
EOF
    chmod 700 "$MONITOR_PATH"
}

# --- 功能函数 ---
install_monitor() {
    echo -e "${WORKING}>> 正在安装守护环境...${NC}"
    write_core_script
    (crontab -l 2>/dev/null | grep -v "$MONITOR_PATH"; echo "*/5 * * * * $MONITOR_PATH > /dev/null 2>&1") | crontab -
    echo -e "${SUCCESS}[成功] 监控已启动，每 5 分钟执行一次检测。${NC}"
    sleep 2
}

uninstall_monitor() {
    echo -e "${WORKING}>> 正在卸载守护环境...${NC}"
    crontab -l 2>/dev/null | grep -v "$MONITOR_PATH" | crontab -
    rm -f "$MONITOR_PATH"
    echo -e "${SUCCESS}[成功] 监控已彻底移除。${NC}"
    sleep 2
}

show_status() {
    echo -e "${INFO}--- 当前运行状态 ---${NC}"
    if crontab -l 2>/dev/null | grep -q "$MONITOR_PATH"; then
        echo -e "状态: ${SUCCESS}正在平稳运行中${NC}"
        [ -f "$LOG_PATH" ] && echo -e "最近日志记录:\n$(tail -n 3 $LOG_PATH)"
    else
        echo -e "状态: ${ERROR}监控未安装${NC}"
    fi
    read -p "按回车键返回菜单..."
}

# --- 主菜单界面 ---
main_menu() {
    while true; do
        show_ad
        echo -e "  ${WORKING}1.${NC} 安装/更新 自动监控"
        echo -e "  ${WORKING}2.${NC} 卸载 自动监控"
        echo -e "  ${WORKING}3.${NC} 查看 运行状态"
        echo -e "  ${WORKING}0.${NC} 退出脚本"
        echo -e "${CONTACT}====================================================${NC}"
        read -p "请输入数字选择: " num

        case "$num" in
            1) install_monitor ;;
            2) uninstall_monitor ;;
            3) show_status ;;
            0) exit 0 ;;
            *) echo -e "${ERROR}输入错误，请重新输入${NC}" ; sleep 1 ;;
        esac
    done
}

# 权限检查
if [ "$EUID" -ne 0 ]; then 
    echo -e "${ERROR}[错误]${NC} 请使用 root 权限运行！"
    exit 1
fi

main_menu
