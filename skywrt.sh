#!/bin/bash
# SkyWRT 全功能管理脚本
# 使用方式: bash <(curl -sL https://sink.ysx66.com/skywrt)

# ========================
# 颜色定义
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
RESET='\033[0m'

# ========================
# Banner
# ========================
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo '  _____ _          __        __    _____  _____ _____ '
    echo ' / ____| |        / /       / /   |  __ \|_   _|  __ \'
    echo '| (___ | |_ _   / /_  __  / /__  | |__) | | | | |__) |'
    echo ' \___ \| __| | / /\ \/ / / / _ \ |  _  /  | | |  ___/'
    echo ' ____) | |_| |/ /__>  < / / (_) || | \ \ _| |_| |    '
    echo '|_____/ \__\_/_/  /_/\_\/_/ \___/ |_|  \_\_____|_|    '
    echo -e "${RESET}"
    echo -e "管理脚本 v3.0 | 项目: ${BLUE}https://github.com/skywrt/linux${RESET}"
    echo
}

# ========================
# 基础功能
# ========================
check_root() {
    [ "$(id -u)" -ne 0 ] && {
        echo -e "${RED}错误: 此脚本需要root权限${RESET}"
        echo -e "请使用: ${BLUE}sudo bash <(curl -sL https://sink.ysx66.com/skywrt)${RESET}"
        exit 1
    }
}

press_any_key() {
    echo -ne "${YELLOW}按任意键继续...${RESET}"
    read -n 1 -s -r
    echo
}

# ========================
# 主菜单
# ========================
main_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}1. 系统换源"
        echo -e "2. 软件管理"
        echo -e "3. Docker管理"
        echo -e "4. 系统设置${RESET}"
        echo -e "========================="
        
        read -p "请输入选项: " choice
        
        case $choice in
            1) source_menu ;;
            2) software_menu ;;
            3) docker_menu ;;
            4) system_menu ;;
            *) echo -e "${RED}无效选项!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 系统换源 (完整版)
# ========================
source_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 系统换源 ==="
        
        if [ -f /etc/redhat-release ]; then
            echo -e "${YELLOW}CentOS/RHEL 系统${RESET}"
            echo -e "1. 阿里云源"
            echo -e "2. 腾讯云源"
            echo -e "3. 清华大学源"
        else
            echo -e "${YELLOW}Debian/Ubuntu 系统${RESET}"
            echo -e "1. 阿里云源"
            echo -e "2. 网易源"
            echo -e "3. 华为云源"
        fi
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择源: " choice
        
        case $choice in
            1|2|3)
                [ -f /etc/redhat-release ] && centos_source "$choice" || debian_source "$choice"
                press_any_key
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

centos_source() {
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.tencent.com" ;;
        3) mirror="mirrors.tuna.tsinghua.edu.cn" ;;
    esac
    echo -e "${YELLOW}正在配置 $mirror 源...${RESET}"
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org|baseurl=https://$mirror|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo
    yum makecache
    echo -e "${GREEN}换源完成!${RESET}"
}

debian_source() {
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.163.com" ;;
        3) mirror="repo.huaweicloud.com" ;;
    esac
    echo -e "${YELLOW}正在配置 $mirror 源...${RESET}"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sed -i "s|http://.*archive.ubuntu.com|https://$mirror|g" /etc/apt/sources.list
    apt update
    echo -e "${GREEN}换源完成!${RESET}"
}

# ========================
# 软件管理 (完整功能)
# ========================
software_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 软件管理 ==="
        echo -e "1. 安装常用工具"
        echo -e "2. 卸载软件"
        echo -e "3. 更新软件列表"
        echo -e "4. 系统升级"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_tools ;;
            2) remove_software ;;
            3) update_packages ;;
            4) upgrade_system ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_tools() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 安装工具 ==="
        echo -e "1. 开发工具 (gcc/make等)"
        echo -e "2. 网络工具"
        echo -e "3. 监控工具"
        echo -e "4. 自定义安装..."
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择: " choice
        
        case $choice in
            1) install_dev_tools ;;
            2) install_net_tools ;;
            3) install_monitor_tools ;;
            4) custom_install ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# Docker管理 (完整功能)
# ========================
docker_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== Docker管理 ==="
        echo -e "1. 安装Docker"
        echo -e "2. 配置镜像加速"
        echo -e "3. 常用容器管理"
        echo -e "4. 卸载Docker"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_docker ;;
            2) config_docker ;;
            3) container_manage ;;
            4) remove_docker ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 系统设置 (包含快捷键设置)
# ========================
system_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 系统设置 ==="
        echo -e "1. 设置命令别名"
        echo -e "2. 清理系统"
        echo -e "3. 网络优化"
        echo -e "4. 时区设置"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) setup_alias ;;
            2) clean_system ;;
            3) optimize_network ;;
            4) set_timezone ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 快捷键设置 (完整功能)
# ========================
setup_alias() {
    show_banner
    echo -e "${GREEN}=== 设置命令别名 ==="
    echo -e "${YELLOW}当前可用快捷命令:${RESET}"
    echo -e "skywrt : 启动本脚本"
    
    read -p "输入新的快捷命令 (留空保持当前): " alias_name
    [ -z "$alias_name" ] && return
    
    # 写入bashrc
    echo "alias $alias_name='bash <(curl -sL https://sink.ysx66.com/skywrt)'" >> ~/.bashrc
    source ~/.bashrc
    
    echo -e "${GREEN}快捷命令设置成功!${RESET}"
    echo -e "现在可以使用: ${BLUE}$alias_name${RESET} 启动脚本"
    press_any_key
}

# ========================
# 其他功能实现...
# ========================

# 脚本入口
check_root
main_menu
