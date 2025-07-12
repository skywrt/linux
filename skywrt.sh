#!/bin/bash
# SkyWRT 终极一键管理脚本 (适配 skywrt.ysx66.com)
# 项目主页: https://github.com/skywrt/linux

# ========================
# 颜色定义
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ========================
# 动态域名配置
# ========================
DOMAIN="skywrt.ysx66.com"  # 您的GitHub Pages域名
FALLBACK_URL="https://raw.githubusercontent.com/skywrt/linux/main/skywrt.sh"

# ========================
# Banner 显示
# ========================
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo '   _____ _          __        __    _____  _____ _____ '
    echo '  / ____| |        / /       / /   |  __ \|_   _|  __ \'
    echo ' | (___ | |_ _   / /_  __  / /__  | |__) | | | | |__) |'
    echo '  \___ \| __| | / /\ \/ / / / _ \ |  _  /  | | |  ___/'
    echo '  ____) | |_| |/ /__>  < / / (_) || | \ \ _| |_| |    '
    echo ' |_____/ \__\_/_/  /_/\_\/_/ \___/ |_|  \_\_____|_|    '
    echo -e "${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    echo -e "${BOLD}         SkyWRT Linux 管理脚本 v2.2${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    echo -e "专属域名: ${GREEN}https://${DOMAIN}${RESET}"
    echo -e "备用命令: ${YELLOW}bash <(curl -sL ${FALLBACK_URL})${RESET}"
    echo
}

# ========================
# 基础功能
# ========================
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要root权限执行${RESET}"
        echo -e "请使用 ${BOLD}sudo bash <(curl -sL https://${DOMAIN})${RESET}"
        exit 1
    fi
}

press_any_key() {
    echo -ne "${YELLOW}按任意键继续...${RESET}"
    read -n 1 -s -r
    echo
}

# ========================
# 主菜单系统
# ========================
main_menu() {
    while true; do
        show_banner
        echo -e "${BOLD}主菜单选项:${RESET}"
        echo -e "${GREEN}1. 系统换源${RESET}    - 更换国内软件源"
        echo -e "${GREEN}2. 一键更新${RESET}    - 升级所有软件包"
        echo -e "${GREEN}3. 工具安装${RESET}    - 常用工具合集"
        echo -e "${GREEN}4. Docker管理${RESET} - 容器环境配置"
        echo -e "${GREEN}5. 网络优化${RESET}    - TCP/网络调优"
        echo -e "${RED}0. 退出脚本${RESET}"
        echo -e "${CYAN}===============================================${RESET}"
        
        read -p "请输入选项数字: " choice
        
        case $choice in
            1) source_menu ;;
            2) upgrade_system ;;
            3) tools_menu ;;
            4) docker_menu ;;
            5) network_tuning ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 系统换源功能
# ========================
source_menu() {
    while true; do
        show_banner
        echo -e "${BOLD}系统换源${RESET}"
        
        # 系统检测
        if [ -f /etc/redhat-release ]; then
            echo -e "检测到: ${YELLOW}CentOS/RHEL 系统${RESET}"
            options=("阿里云" "腾讯云" "华为云" "清华大学")
        elif grep -qi "debian" /etc/os-release; then
            echo -e "检测到: ${YELLOW}Debian 系统${RESET}"
            options=("阿里云" "网易" "华为云" "清华大学")
        elif grep -qi "ubuntu" /etc/os-release; then
            echo -e "检测到: ${YELLOW}Ubuntu 系统${RESET}"
            options=("阿里云" "清华TUNA" "中科大" "网易")
        else
            echo -e "${RED}不支持的系统类型${RESET}"
            press_any_key
            return
        fi
        
        # 显示选项
        for i in "${!options[@]}"; do
            echo -e "${GREEN}$((i+1)). ${options[i]}${RESET}"
        done
        echo -e "${CYAN}===============================================${RESET}"
        echo -e "${BLUE}b. 返回主菜单${RESET}  ${RED}0. 退出${RESET}"
        
        read -p "请选择镜像源: " choice
        
        case $choice in
            [1-4]) 
                echo -e "${YELLOW}正在更换为 ${options[$((choice-1))]} 源...${RESET}"
                change_source "${options[$((choice-1))]}"
                press_any_key
                ;;
            b|B) return ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

change_source() {
    local source_name=$1
    echo -e "${GREEN}开始配置 $source_name 镜像源...${RESET}"
    
    # 实际换源操作（示例）
    case $source_name in
        "阿里云") mirror="mirrors.aliyun.com" ;;
        "腾讯云") mirror="mirrors.tencent.com" ;;
        *) mirror="mirrors.tuna.tsinghua.edu.cn" ;;
    esac
    
    # 备份原有源
    cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || 
    cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null
    
    echo -e "${YELLOW}正在更新软件列表...${RESET}"
    if command -v apt &>/dev/null; then
        sed -i "s|http://.*archive.ubuntu.com|https://$mirror|g" /etc/apt/sources.list
        apt update
    elif command -v yum &>/dev/null; then
        sed -i "s|mirror.centos.org|$mirror|g" /etc/yum.repos.d/CentOS-Base.repo
        yum makecache
    fi
    
    echo -e "${GREEN}$source_name 镜像源配置完成!${RESET}"
}

# ========================
# 其他核心功能
# ========================
upgrade_system() {
    show_banner
    echo -e "${BOLD}系统升级${RESET}"
    echo -e "${YELLOW}正在升级系统...${RESET}"
    
    if command -v apt &>/dev/null; then
        apt update && apt upgrade -y
    elif command -v yum &>/dev/null; then
        yum update -y
    elif command -v dnf &>/dev/null; then
        dnf upgrade -y
    else
        echo -e "${RED}不支持的包管理器${RESET}"
    fi
    
    echo -e "${GREEN}系统升级完成!${RESET}"
    press_any_key
}

docker_menu() {
    while true; do
        show_banner
        echo -e "${BOLD}Docker 管理${RESET}"
        echo -e "${GREEN}1. 安装 Docker${RESET}"
        echo -e "${GREEN}2. 配置镜像加速${RESET}"
        echo -e "${GREEN}3. 常用容器部署${RESET}"
        echo -e "${CYAN}===============================================${RESET}"
        echo -e "${BLUE}b. 返回主菜单${RESET}  ${RED}0. 退出${RESET}"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_docker ;;
            2) config_docker_mirror ;;
            3) deploy_containers ;;
            b|B) return ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_docker() {
    show_banner
    echo -e "${YELLOW}正在安装 Docker...${RESET}"
    
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}Docker 已安装: $(docker --version)${RESET}"
    else
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        echo -e "${GREEN}Docker 安装成功!${RESET}"
    fi
    
    press_any_key
}

# ========================
# 脚本入口
# ========================
check_root
main_menu
