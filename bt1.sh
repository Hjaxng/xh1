#!/bin/bash

# 环境编码声明
export LANG=en_US.UTF-8

# 颜色定义
INFO='\033[0;36m'  # 青色
SUCCESS='\033[0;32m' # 绿色
WORKING='\033[1;33m' # 黄色
ERROR='\033[0;31m'   # 红色
NC='\033[0m'         # 重置

# --- 简洁版页眉 ---
show_header() {
    clear
    echo -e "${INFO}----------------------------------------------------${NC}"
    echo -e "  宝塔面板守护脚本：自动检测面板是否存活，告别面板假死
    echo -e "${INFO}----------------------------------------------------${NC}"
}

# --- 简洁版页脚 ---
show_footer() {
    echo ""
    echo -e "${INFO}----------------------------------------------------${NC}"
    echo -e " 优质服务器资源 | 联系Telegram: @hjaxng"
    echo -e "${INFO}----------------------------------------------------${NC}"
}

# 配置路径
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="check_panel.sh"
TARGET_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# --- 核心监控逻辑 (增加重试, 不留日志) ---
write_core_script() {
    cat > "$TARGET_PATH" << 'EOF'
#!/bin/bash
# 从配置文件获取端口，默认8888
PORT=$(cat /www/server/panel/data/port.pl 2>/dev/null || echo "8888")

# 单次检测函数
single_check() {
    curl -sk --connect-timeout 5 "https://127.0.0.1:$PORT" > /dev/null 2>&1 || \
    curl -sk --connect-timeout 5 "http://127.0.0.1:$PORT" > /dev/null 2>&1
}

# 连续 3 次检测机制
FAIL_COUNT=0
for i in {1..3}; do
    if single_check; then
        exit 0 # 只要有一次成功，直接正常退出，不记录任何东西
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        sleep 3 # 失败后等待 3 秒再试
    fi
done

# 如果连续 3 次都失败，则执行重启
if [ $FAIL_COUNT -eq 3 ]; then
    bt 1 > /dev/null 2>&1
fi
EOF
    chmod +x "$TARGET_PATH"
}

# --- 安装 ---
install_monitor() {
    echo -e "${WORKING}>> 正在部署监控服务...${NC}"
    write_core_script
    # 清理旧任务并添加新任务，不产生系统日志邮件
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | grep -v "bt 1"; echo "*/5 * * * * $TARGET_PATH > /dev/null 2>&1") | crontab -
    echo -e "${SUCCESS}[完毕] 服务已启动。已配置连续3次检测失败才触发重启。${NC}"
}

# --- 卸载 ---
uninstall_monitor() {
    echo -e "${WORKING}>> 正在移除监控服务...${NC}"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME") | crontab -
    rm -f "$TARGET_PATH"
    # 同时清理可能存在的旧日志文件
    rm -f /tmp/panel_monitor.log
    echo -e "${SUCCESS}[完毕] 服务已彻底清除。${NC}"
}

# --- 状态 ---
show_status() {
    echo -e "${INFO}[运行状态]:${NC}"
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        echo -e "  - 定时任务: ${SUCCESS}已开启 (3次重试机制)${NC}"
        echo -e "  - 运行模式: ${SUCCESS}静默运行 (无日志)${NC}"
    else
        echo -e "  - 定时任务: ${ERROR}未配置${NC}"
    fi
}

# --- 主菜单 ---
main_menu() {
    show_header
    show_status
    echo ""
    echo -e "  ${WORKING}1.${NC} 开启/更新 自动监控"
    echo -e "  ${WORKING}2.${NC} 停止/卸载 自动监控"
    echo -e "  ${WORKING}0.${NC} 退出程序"
    show_footer
    read -p "请选择操作: " num

    case "$num" in
        1) install_monitor ;;
        2) uninstall_monitor ;;
        0) exit 0 ;;
        *) echo -e "${ERROR}无效输入${NC}" ; sleep 1 ; main_menu ;;
    esac
}

if [ "$EUID" -ne 0 ]; then 
    echo -e "${ERROR}[错误]${NC} 请使用 root 权限执行。"
    exit 1
fi

main_menu
