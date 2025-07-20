#!/bin/bash
# SkyWRT Linux 管理脚本
# 版本: 0.0.1
# 说明: 仅提供菜单功能和脚本更新功能

# ========================
# 颜色定义
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ========================
# 全局变量
# ========================
SH_VERSION="0.0.1"
FALLBACK_URL="https://raw.githubusercontent.com/skywrt/linux/main/skywrt.sh"

# ========================
# Banner 显示
# ========================
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo '            __            _       __           __ '
    echo '   _____   / /__   __  __| |     / /   _____  / /_'
    echo '  / ___/  / //_/  / / / /| | /| / /   / ___/ / __/'
    echo ' (__  )  / ,<    / /_/ / | |/ |/ /   / /    / /_  '
    echo '/____/  /_/|_|   \__, /  |__/|__/   /_/     \__/  '
    echo '                /____/                            '
    echo -e "${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    echo -e "${BOLD}         SkyWRT Linux 管理脚本 v${SH_VERSION}${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    echo
}

# ========================
# 脚本更新
# ========================
update_script() {
    clear
    echo -e "${CYAN}更新 SkyWRT 脚本${RESET}"
    echo "------------------------"
    local sh_v_new=$(curl -s $FALLBACK_URL | grep -o 'SH_VERSION="[0-9.]*"' | cut -d '"' -f 2)

    if [ "$SH_VERSION" = "$sh_v_new" ]; then
        echo -e "${GREEN}你已经是最新版本！${YELLOW}v$SH_VERSION${RESET}"
    else
        echo -e "发现新版本！当前版本 v$SH_VERSION 最新版本 ${YELLOW}v$sh_v_new${RESET}"
        read -e -p "是否更新到最新版本？(y/n): " update_choice
        if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
            curl -sS -o /root/skywrt.sh $FALLBACK_URL && chmod +x /root/skywrt.sh
            echo -e "${GREEN}脚本已更新到最新版本！${YELLOW}v$sh_v_new${RESET}"
            break_end
            /root/skywrt.sh
            exit
        else
            echo -e "${YELLOW}已取消更新${RESET}"
        fi
    fi
    break_end
}

# ========================
# 操作完成提示
# ========================
break_end() {
    echo -e "${GREEN}操作完成${RESET}"
    echo "按任意键继续..."
    read -n 1 -s -r
    clear
}

# ========================
# 主菜单
# ========================
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}功能菜单${RESET}"
        echo "------------------------"
        echo "1. 系统换源（未实现）"
        echo "2. 安装常用工具（未实现）"
        echo "3. Docker 管理（未实现）"
        echo "4. 脚本更新"
        echo "------------------------"
        echo "0. 退出脚本"
        echo "------------------------"
        read -e -p "请输入你的选择: " choice

        case $choice in
            1|2|3)
                echo -e "${YELLOW}此功能尚未实现${RESET}"
                break_end
                ;;
            4)
                update_script
                ;;
            0)
                clear
                exit
                ;;
            *)
                echo -e "${RED}无效的输入!${RESET}"
                break_end
                ;;
        esac
    done
}

# ========================
# 脚本入口
# ========================
main_menu
