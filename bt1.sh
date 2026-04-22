#!/bin/bash

# 环境编码声明
export LANG=en_US.UTF-8

# 颜色定义
INFO='\033[0;36m'     # 青色 (主要用于边框和标题)
SUCCESS='\033[0;32m'  # 绿色 (用于成功提示)
WORKING='\033[1;33m'  # 黄色 (用于选项数字)
CONTACT='\033[1;35m'  # 淡紫色 (专属联系方式颜色，低调高雅)
ERROR='\033[0;31m'    # 红色 (用于报错)
NC='\033[0m'          # 重置颜色

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
    echo -e " [服务器资源] 联系Telegram: ${CONTACT}@hjaxng${NC}"
    echo -e "${INFO}----------------------------------------------------${NC}"
}

# 配置路径
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="check_panel.sh"
TARGET_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# --- 核心监控逻辑 (3次重试, 静默模式) ---
write_core_script() {
    cat > "$TARGET_PATH" << 'EOF'
#!/bin/bash
PORT=$(cat /www/server/panel/data/port.pl 2>/dev/null || echo "8888")
single_check() {
    curl -sk --connect-timeout 5 "https://127.0.0.1:$PORT" > /dev/null 2>&1 || \
    curl -sk --connect-timeout 5 "http://127.0.0.1:$PORT" > /dev/null 2>&1
}
FAIL_COUNT=0
for i in {1..3}; do
    if single_check; then
        exit 0
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        sleep 3
    fi
done
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
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | grep -v "bt 1"; echo "*/5 * * * * $TARGET_PATH > /dev/null 2>&1") | crontab -
    echo -e "${SUCCESS}[完毕] 服务已启动。已配置 3 次重试及静默模式。${NC}"
}

# --- 卸载 ---
uninstall_monitor() {
    echo -e "${WORKING}>> 正在移除监控服务...${NC}"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME") | crontab -
    rm -f "$TARGET_PATH"
    echo -e "${SUCCESS}[完毕] 相关服务已彻底清除。${NC}"
}

# --- 状态预览 ---
show_status() {
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        echo -e " 当前状态: ${SUCCESS}自动监测中${NC}"
    else
        echo -e " 当前状态: ${ERROR}未开启${NC}"
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
