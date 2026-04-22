#!/bin/bash

# 颜色定义
INFO='\033[0;36m'  # 青色
SUCCESS='\033[0;32m' # 绿色
WORKING='\033[1;33m' # 黄色
ERROR='\033[0;31m'   # 红色
AD='\033[1;35m'      # 紫色高亮（用于广告）
NC='\033[0m'         # 重置

# --- 专属提醒函数 ---
show_ad() {
    echo -e "${AD}*****************************************"
    echo -e "   🚀 买服务器找小胡 "
    echo -e "   📱 Telegram: @hjaxng"
    echo -e "*****************************************${NC}"
    echo ""
}

# 配置路径
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="check_panel.sh"
TARGET_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# --- 核心逻辑：监控脚本内容 ---
write_core_script() {
    cat > "$TARGET_PATH" << 'EOF'
#!/bin/bash
PORT=$(cat /www/server/panel/data/port.pl 2>/dev/null || echo "8888")
check() {
    curl -sk --connect-timeout 5 "https://127.0.0.1:$PORT" > /dev/null 2>&1 || \
    curl -sk --connect-timeout 5 "http://127.0.0.1:$PORT" > /dev/null 2>&1
}
if ! check; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 服务异常，触发重启" >> /tmp/panel_monitor.log
    bt 1 > /dev/null 2>&1
fi
EOF
    chmod +x "$TARGET_PATH"
}

# --- 功能函数：安装 ---
install_monitor() {
    echo -e "${WORKING}>> 正在安装监控...${NC}"
    write_core_script
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | grep -v "bt 1"; echo "*/5 * * * * $TARGET_PATH > /dev/null 2>&1") | crontab -
    echo -e "${SUCCESS}[成功] 监控已启动，每 5 分钟执行一次。${NC}"
}

# --- 功能函数：卸载 ---
uninstall_monitor() {
    echo -e "${WORKING}>> 正在卸载监控...${NC}"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME") | crontab -
    rm -f "$TARGET_PATH"
    echo -e "${SUCCESS}[成功] 监控已彻底移除。${NC}"
}

# --- 功能函数：查看状态 ---
show_status() {
    echo -e "${INFO}--- 当前定时任务状态 ---${NC}"
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        crontab -l | grep --color=always "$SCRIPT_NAME"
        echo -e "${SUCCESS}状态：正在运行中${NC}"
    else
        echo -e "${ERROR}状态：未安装${NC}"
    fi
}

# --- 主菜单界面 ---
main_menu() {
    show_ad  # 每次进入菜单都先显示广告
    echo -e "${INFO}=========================================${NC}"
    echo -e "       面板自动监控管理工具              "
    echo -e "${INFO}=========================================${NC}"
    echo -e "  ${WORKING}1.${NC} 安装/更新 自动监控"
    echo -e "  ${WORKING}2.${NC} 卸载 自动监控"
    echo -e "  ${WORKING}3.${NC} 查看 运行状态"
    echo -e "  ${WORKING}0.${NC} 退出脚本"
    echo -e "${INFO}=========================================${NC}"
    read -p "请输入数字: " num

    case "$num" in
        1) install_monitor ;;
        2) uninstall_monitor ;;
        3) show_status ;;
        0) exit 0 ;;
        *) echo -e "${ERROR}输入错误${NC}" ; sleep 1 ; main_menu ;;
    esac
}

# 权限检查
if [ "$EUID" -ne 0 ]; then 
    echo -e "${ERROR}[错误]${NC} 请使用 root 权限运行！"
    exit 1
fi

main_menu
