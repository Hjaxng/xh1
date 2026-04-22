#!/bin/bash

# 颜色定义
INFO='\033[0;36m'  # 青色
SUCCESS='\033[0;32m' # 绿色
WORKING='\033[1;33m' # 黄色
ERROR='\033[0;31m'   # 红色
HIGHLIGHT='\033[1;35m' # 紫色
NC='\033[0m'         # 重置

# 配置路径
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="check_panel.sh"
TARGET_PATH="$INSTALL_DIR/$SCRIPT_NAME"

# --- 卸载逻辑 ---
do_uninstall() {
    echo -e "${WORKING}>> 正在启动卸载程序...${NC}"
    
    # 1. 移除定时任务
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME") | crontab -
        echo -e "${SUCCESS}[完毕] 定时任务已移除${NC}"
    else
        echo -e "${INFO}[跳过] 未发现相关的定时任务${NC}"
    fi

    # 2. 删除脚本文件
    if [ -f "$TARGET_PATH" ]; then
        rm -f "$TARGET_PATH"
        echo -e "${SUCCESS}[完毕] 脚本文件已删除 ($TARGET_PATH)${NC}"
    else
        echo -e "${INFO}[跳过] 脚本文件不存在${NC}"
    fi

    echo -e "${INFO}====================================================${NC}"
    echo -e "${SUCCESS}      面板监控脚本已成功从您的系统中移除！          ${NC}"
    echo -e "${INFO}====================================================${NC}"
    exit 0
}

# --- 安装逻辑 ---
do_install() {
    echo -e "${INFO}====================================================${NC}"
    echo -e "${INFO}       面板服务自动监控 [安装/卸载一体版]           ${NC}"
    echo -e "${INFO}====================================================${NC}"

    # 权限检测
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${ERROR}[错误]${NC} 请使用 root 权限运行！"
        exit 1
    fi

    echo -e "${WORKING}>> [1/3] 正在配置监控脚本...${NC}"
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
    echo -e "${SUCCESS}[成功] 脚本位置: $TARGET_PATH${NC}"

    echo -e "${WORKING}>> [2/3] 正在配置定时任务...${NC}"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | grep -v "bt 1"; echo "*/5 * * * * $TARGET_PATH > /dev/null 2>&1") | crontab -
    
    echo -e "${WORKING}>> [3/3] 正在验证安装结果...${NC}"
    sleep 1
    echo -e "${INFO}----------------------------------------------------${NC}"
    echo -e "${SUCCESS}部署已完成！当前定时任务列表：${NC}"
    crontab -l | grep --color=always -E "$SCRIPT_NAME|$"
    echo -e "${INFO}----------------------------------------------------${NC}"
    echo -e "卸载命令: ${HIGHLIGHT}bash $0 uninstall${NC}"
    echo -e "${INFO}====================================================${NC}"
}

# --- 主程序入口 ---
# 判断执行参数
if [ "$1" == "uninstall" ]; then
    do_uninstall
else
    do_install
fi
