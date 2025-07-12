#!/bin/bash
# SkyWRT Linux 管理脚本
# 使用方式: bash <(curl -sL https://sink.ysx66.com/linux)
# 版本: 2.3
# 说明: 支持系统换源、常用工具、Docker 管理、系统设置、设置快捷键、脚本更新。

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
DOMAIN="https://sink.ysx66.com/linux"
FALLBACK_URL="https://raw.githubusercontent.com/skywrt/linux/main/skywrt.sh"

# ========================
# 全局变量
# ========================
SH_VERSION="2.3"

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
    echo -e "${BOLD}         SkyWRT Linux 管理脚本 v${SH_VERSION}${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    echo -e "脚本命令: ${GREEN}bash <(curl -sL ${DOMAIN})${RESET}"
    echo -e "备用命令: ${YELLOW}bash <(curl -sL ${FALLBACK_URL})${RESET}"
    echo
}

# ========================
# 基础功能
# ========================
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要root权限${RESET}"
        echo -e "请使用: ${BLUE}bash <(curl -sL ${DOMAIN})${RESET}"
        exit 1
    fi
}

press_any_key() {
    echo -ne "${YELLOW}按任意键继续...${RESET}"
    read -n 1 -s -r
    echo
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_disk_space() {
    local required_gb=$1
    local required_space_mb=$((required_gb * 1024))
    local available_space_mb
    available_space_mb=$(df -m / | awk 'NR==2 {print $4}' 2>/dev/null || echo 0)
    if [ "$available_space_mb" -eq 0 ]; then
        echo -e "${YELLOW}警告: 无法获取磁盘空间信息，跳过检查${RESET}"
        return
    fi
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo -e "${YELLOW}警告: 磁盘空间不足！可用: $((available_space_mb/1024))G，需求: ${required_gb}G${RESET}"
        echo -e "${YELLOW}磁盘空间不足，无法继续！${RESET}"
        press_any_key
        exit 1
    fi
}

get_system_version() {
    if [ -f /etc/armbian-release ]; then
        echo -e "${YELLOW}当前系统: Armbian $(grep VERSION /etc/armbian-release | cut -d '=' -f 2)${RESET}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${YELLOW}当前系统: $(cat /etc/redhat-release)${RESET}"
    elif [ -f /etc/os-release ]; then
        echo -e "${YELLOW}当前系统: $(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)${RESET}"
    else
        echo -e "${YELLOW}当前系统: 未知${RESET}"
    fi
}

# ========================
# 主菜单
# ========================
main_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}1. 系统换源"
        echo -e "2. 安装常用工具"
        echo -e "3. Docker管理"
        echo -e "4. 系统设置"
        echo -e "5. 设置快捷键"
        echo -e "6. 脚本更新${RESET}"
        echo -e "${BLUE}0. 退出${RESET}"
        echo -e "========================="
        
        read -p "请输入选项: " choice
        
        case $choice in
            1) source_menu ;;
            2) software_menu ;;
            3) docker_menu ;;
            4) system_menu ;;
            5) setup_alias ;;
            6) update_script ;;
            0) echo -e "${GREEN}退出 SkyWRT 脚本${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 系统换源
# ========================
source_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 系统换源 ==="
        get_system_version
        if [ -f /etc/redhat-release ]; then
            echo -e "1. 阿里云源"
            echo -e "2. 腾讯云源"
            echo -e "3. 清华大学源"
        elif [ -f /etc/armbian-release ]; then
            echo -e "1. Armbian 换源"
        else
            echo -e "1. 阿里云源"
            echo -e "2. 网易源"
            echo -e "3. 华为云源"
        fi
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择源: " choice
        
        if [ -f /etc/redhat-release ]; then
            case $choice in
                1|2|3) centos_source "$choice"; press_any_key ;;
                0) return ;;
                *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
            esac
        elif [ -f /etc/armbian-release ]; then
            case $choice in
                1) armbian_source_menu ;;
                0) return ;;
                *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
            esac
        else
            case $choice in
                1|2|3) debian_source "$choice"; press_any_key ;;
                0) return ;;
                *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
            esac
        fi
    done
}

centos_source() {
    local mirror
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.tencent.com" ;;
        3) mirror="mirrors.tuna.tsinghua.edu.cn" ;;
    esac
    
    echo -e "${GREEN}开始配置 $mirror 源...${RESET}"
    if [ ! -d /etc/yum.repos.d ]; then
        echo -e "${RED}Yum配置文件目录不存在${RESET}"
        return 1
    fi
    
    mkdir -p /etc/yum.repos.d/backup
    cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org|baseurl=https://$mirror|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo
    if yum makecache; then
        echo -e "${GREEN}换源完成!${RESET}"
    else
        echo -e "${RED}换源失败!${RESET}"
    fi
}

debian_source() {
    local mirror
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.163.com" ;;
        3) mirror="repo.huaweicloud.com" ;;
    esac
    
    echo -e "${GREEN}开始配置 $mirror 源...${RESET}"
    if [ ! -f /etc/apt/sources.list ]; then
        echo -e "${RED}APT配置文件不存在${RESET}"
        return 1
    fi
    
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sed -i "s|http://.*archive.ubuntu.com|https://$mirror|g" /etc/apt/sources.list
    if apt update; then
        echo -e "${GREEN}换源完成!${RESET}"
    else
        echo -e "${RED}换源失败!${RESET}"
    fi
}

armbian_source_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== Armbian 换源 ==="
        get_system_version
        echo -e "1. 备份现有源文件"
        echo -e "2. 修改 Debian 主源 (debian.sources)"
        echo -e "3. 修改 Armbian 专用源 (armbian.sources)"
        echo -e "4. 导入 Armbian GPG 密钥"
        echo -e "5. 更新软件"
        echo -e "6. 升级内核"
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) armbian_backup_sources ;;
            2) armbian_modify_debian_sources ;;
            3) armbian_modify_armbian_sources ;;
            4) armbian_import_gpg_key ;;
            5) armbian_update_software ;;
            6) armbian_update_kernel ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

armbian_backup_sources() {
    echo -e "${GREEN}开始备份 Armbian 源文件...${RESET}"
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
        echo -e "${GREEN}已备份 /etc/apt/sources.list.d/debian.sources${RESET}"
    else
        echo -e "${YELLOW}警告: 未找到 /etc/apt/sources.list.d/debian.sources，跳过备份${RESET}"
    fi
    if [ -f /etc/apt/sources.list.d/armbian.sources ]; then
        cp /etc/apt/sources.list.d/armbian.sources /etc/apt/sources.list.d/armbian.sources.bak
        echo -e "${GREEN}已备份 /etc/apt/sources.list.d/armbian.sources${RESET}"
    else
        echo -e "${YELLOW}警告: 未找到 /etc/apt/sources.list.d/armbian.sources，跳过备份${RESET}"
    fi
    press_any_key
}

armbian_modify_debian_sources() {
    echo -e "${GREEN}开始修改 Debian 主源 (debian.sources)...${RESET}"
    if [ ! -f /etc/apt/sources.list.d/debian.sources ]; then
        echo -e "${RED}错误: /etc/apt/sources.list.d/debian.sources 不存在${RESET}"
        press_any_key
        return 1
    fi
    cat > /etc/apt/sources.list.d/debian.sources << EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/debian/
Suites: bookworm bookworm-updates bookworm-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirrors.ustc.edu.cn/debian-security/
Suites: bookworm-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Debian 主源修改成功${RESET}"
    else
        echo -e "${RED}Debian 主源修改失败${RESET}"
    fi
    press_any_key
}

armbian_modify_armbian_sources() {
    echo -e "${GREEN}开始修改 Armbian 专用源 (armbian.sources)...${RESET}"
    if [ ! -f /etc/apt/sources.list.d/armbian.sources ]; then
        echo -e "${RED}错误: /etc/apt/sources.list.d/armbian.sources 不存在${RESET}"
        press_any_key
        return 1
    fi
    cat > /etc/apt/sources.list.d/armbian.sources << EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/armbian/
Suites: bookworm
Components: main bookworm-utils bookworm-desktop
Signed-By: /usr/share/keyrings/armbian.key
EOF
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Armbian 专用源修改成功${RESET}"
    else
        echo -e "${RED}Armbian 专用源修改失败${RESET}"
    fi
    press_any_key
}

armbian_import_gpg_key() {
    echo -e "${GREEN}开始导入 Armbian GPG 密钥...${RESET}"
    if [ -f /usr/share/keyrings/armbian.key ]; then
        echo -e "${YELLOW}Armbian GPG 密钥已存在${RESET}"
        press_any_key
        return
    fi
    if curl -fsSL https://apt.armbian.com/armbian.key | gpg --dearmor -o /usr/share/keyrings/armbian.key; then
        echo -e "${GREEN}Armbian GPG 密钥导入成功${RESET}"
    else
        echo -e "${RED}Armbian GPG 密钥导入失败${RESET}"
    fi
    press_any_key
}

armbian_update_software() {
    echo -e "${GREEN}开始更新软件...${RESET}"
    if apt update -y && apt upgrade -y && apt install -y curl wget nano; then
        echo -e "${GREEN}软件更新完成${RESET}"
    else
        echo -e "${RED}软件更新失败${RESET}"
    fi
    press_any_key
}

armbian_update_kernel() {
    echo -e "${GREEN}开始升级内核...${RESET}"
    if ! check_command armbian-update; then
        echo -e "${RED}错误: armbian-update 命令未找到，请先安装${RESET}"
        press_any_key
        return 1
    fi
    if armbian-update -r zwrt/kernel -u stable -k 6.12.36; then
        echo -e "${GREEN}内核升级到 6.12.36 成功${RESET}"
    else
        echo -e "${RED}内核升级失败${RESET}"
    fi
    press_any_key
}

# ========================
# 常用工具
# ========================
software_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 常用工具 ==="
        echo -e "0. 全部安装"
        echo -e "1. curl"
        echo -e "2. wget"
        echo -e "3. git"
        echo -e "4. vim"
        echo -e "5. nano"
        echo -e "6. htop"
        echo -e "7. tmux"
        echo -e "8. unzip"
        echo -e "9. tree"
        echo -e "${BLUE}10. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择要安装的工具: " choice
        
        case $choice in
            0) install_all_tools ;;
            1) install_single_tool "curl" ;;
            2) install_single_tool "wget" ;;
            3) install_single_tool "git" ;;
            4) install_single_tool "vim" ;;
            5) install_single_tool "nano" ;;
            6) install_single_tool "htop" ;;
            7) install_single_tool "tmux" ;;
            8) install_single_tool "unzip" ;;
            9) install_single_tool "tree" ;;
            10) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_all_tools() {
    echo -e "${GREEN}开始安装所有常用工具...${RESET}"
    local tools="curl wget git vim nano htop tmux unzip tree"
    if [ -f /etc/redhat-release ]; then
        if ! yum install -y epel-release; then
            echo -e "${RED}无法安装 epel-release${RESET}"
            press_any_key
            return 1
        fi
        if yum install -y $tools; then
            echo -e "${GREEN}所有工具安装成功${RESET}"
        else
            echo -e "${RED}部分或全部工具安装失败${RESET}"
        fi
    else
        if apt update; then
            if apt install -y $tools; then
                echo -e "${GREEN}所有工具安装成功${RESET}"
            else
                echo -e "${RED}部分或全部工具安装失败${RESET}"
            fi
        else
            echo -e "${RED}更新软件源失败${RESET}"
        fi
    fi
    press_any_key
}

install_single_tool() {
    local tool=$1
    echo -e "${GREEN}开始安装 $tool...${RESET}"
    if check_command "$tool"; then
        echo -e "${YELLOW}$tool 已安装${RESET}"
        press_any_key
        return
    fi
    if [ -f /etc/redhat-release ]; then
        if ! yum install -y epel-release; then
            echo -e "${RED}无法安装 epel-release${RESET}"
            press_any_key
            return 1
        fi
        if yum install -y "$tool"; then
            echo -e "${GREEN}$tool 安装成功${RESET}"
        else
            echo -e "${RED}$tool 安装失败${RESET}"
        fi
    else
        if apt update; then
            if apt install -y "$tool"; then
                echo -e "${GREEN}$tool 安装成功${RESET}"
            else
                echo -e "${RED}$tool 安装失败${RESET}"
            fi
        else
            echo -e "${RED}更新软件源失败${RESET}"
        fi
    fi
    press_any_key
}

# ========================
# Docker管理
# ========================
docker_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== Docker管理 ==="
        echo -e "1. 安装Docker"
        echo -e "2. 配置镜像加速"
        echo -e "3. 容器管理"
        echo -e "4. 镜像管理"
        echo -e "5. 卸载Docker"
        echo -e "6. 开启/关闭IPv6"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) install_docker ;;
            2) config_docker ;;
            3) docker_ps ;;
            4) docker_image ;;
            5) remove_docker ;;
            6) docker_ipv6_menu ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_docker() {
    echo -e "${GREEN}开始安装Docker...${RESET}"
    if check_command docker; then
        echo -e "${YELLOW}Docker已安装${RESET}"
        press_any_key
        return
    fi
    
    local country=$(curl -s ipinfo.io/country || echo "unknown")
    if [ "$country" = "CN" ]; then
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    else
        curl -fsSL https://get.docker.com | sh
    fi
    if systemctl enable docker && systemctl start docker; then
        echo -e "${GREEN}Docker安装成功${RESET}"
    else
        echo -e "${RED}Docker安装失败${RESET}"
    fi
    press_any_key
}

config_docker() {
    echo -e "${GREEN}开始配置Docker镜像加速...${RESET}"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://registry.docker-cn.com",
    "https://mirror.ccs.tencentyun.com"
  ]
}
EOF
    if systemctl restart docker; then
        echo -e "${GREEN}Docker镜像加速配置成功${RESET}"
    else
        echo -e "${RED}Docker镜像加速配置失败${RESET}"
    fi
    press_any_key
}

docker_ps() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 容器管理 ==="
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo -e "------------------------"
        echo -e "1. 创建新容器"
        echo -e "2. 启动指定容器"
        echo -e "3. 停止指定容器"
        echo -e "4. 删除指定容器"
        echo -e "5. 重启指定容器"
        echo -e "6. 启动所有容器"
        echo -e "7. 停止所有容器"
        echo -e "8. 删除所有容器"
        echo -e "9. 进入指定容器"
        echo -e "10. 查看容器日志"
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                read -p "请输入创建命令: " docker_cmd
                if eval "$docker_cmd"; then
                    echo -e "${GREEN}容器创建成功${RESET}"
                else
                    echo -e "${RED}容器创建失败${RESET}"
                fi
                ;;
            2)
                read -p "请输入容器名或ID: " container
                if docker start "$container"; then
                    echo -e "${GREEN}容器 $container 启动成功${RESET}"
                else
                    echo -e "${RED}容器 $container 启动失败${RESET}"
                fi
                ;;
            3)
                read -p "请输入容器名或ID: " container
                if docker stop "$container"; then
                    echo -e "${GREEN}容器 $container 停止成功${RESET}"
                else
                    echo -e "${RED}容器 $container 停止失败${RESET}"
                fi
                ;;
            4)
                read -p "请输入容器名或ID: " container
                if docker rm -f "$container"; then
                    echo -e "${GREEN}容器 $container 删除成功${RESET}"
                else
                    echo -e "${RED}容器 $container 删除失败${RESET}"
                fi
                ;;
            5)
                read -p "请输入容器名或ID: " container
                if docker restart "$container"; then
                    echo -e "${GREEN}容器 $container 重启成功${RESET}"
                else
                    echo -e "${RED}容器 $container 重启失败${RESET}"
                fi
                ;;
            6)
                if docker start $(docker ps -a -q); then
                    echo -e "${GREEN}所有容器启动成功${RESET}"
                else
                    echo -e "${RED}部分或全部容器启动失败${RESET}"
                fi
                ;;
            7)
                if docker stop $(docker ps -q); then
                    echo -e "${GREEN}所有容器停止成功${RESET}"
                else
                    echo -e "${RED}部分或全部容器停止失败${RESET}"
                fi
                ;;
            8)
                read -p "确认删除所有容器？(y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    if docker rm -f $(docker ps -a -q); then
                        echo -e "${GREEN}所有容器删除成功${RESET}"
                    else
                        echo -e "${RED}部分或全部容器删除失败${RESET}"
                    fi
                fi
                ;;
            9)
                read -p "请输入容器名或ID: " container
                docker exec -it "$container" /bin/sh || echo -e "${RED}进入容器 $container 失败${RESET}"
                ;;
            10)
                read -p "请输入容器名或ID: " container
                docker logs "$container" || echo -e "${RED}查看容器 $container 日志失败${RESET}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

docker_image() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 镜像管理 ==="
        docker image ls
        echo -e "------------------------"
        echo -e "1. 拉取指定镜像"
        echo -e "2. 更新指定镜像"
        echo -e "3. 删除指定镜像"
        echo -e "4. 删除所有镜像"
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                read -p "请输入镜像名: " image
                if docker pull "$image"; then
                    echo -e "${GREEN}镜像 $image 拉取成功${RESET}"
                else
                    echo -e "${RED}镜像 $image 拉取失败${RESET}"
                fi
                ;;
            2)
                read -p "请输入镜像名: " image
                if docker pull "$image"; then
                    echo -e "${GREEN}镜像 $image 更新成功${RESET}"
                else
                    echo -e "${RED}镜像 $image 更新失败${RESET}"
                fi
                ;;
            3)
                read -p "请输入镜像名: " image
                if docker rmi -f "$image"; then
                    echo -e "${GREEN}镜像 $image 删除成功${RESET}"
                else
                    echo -e "${RED}镜像 $image 删除失败${RESET}"
                fi
                ;;
            4)
                read -p "确认删除所有镜像？(y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    if docker rmi -f $(docker images -q); then
                        echo -e "${GREEN}所有镜像删除成功${RESET}"
                    else
                        echo -e "${RED}部分或全部镜像删除失败${RESET}"
                    fi
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

remove_docker() {
    echo -e "${GREEN}开始卸载Docker...${RESET}"
    if [ -f /etc/redhat-release ]; then
        yum remove -y docker docker-ce
    else
        apt remove -y docker docker.io containerd runc
    fi
    rm -rf /var/lib/docker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker卸载成功${RESET}"
    else
        echo -e "${RED}Docker卸载失败${RESET}"
    fi
    press_any_key
}

docker_ipv6_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== Docker IPv6管理 ==="
        echo -e "1. 开启Docker IPv6"
        echo -e "2. 关闭Docker IPv6"
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) docker_ipv6_on ;;
            2) docker_ipv6_off ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

docker_ipv6_on() {
    echo -e "${GREEN}开始配置Docker IPv6...${RESET}"
    if ! check_command jq; then
        if [ -f /etc/redhat-release ]; then
            yum install -y jq
        else
            apt install -y jq
        fi
    fi
    local CONFIG_FILE="/etc/docker/daemon.json"
    local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$REQUIRED_IPV6_CONFIG" | jq . > "$CONFIG_FILE"
        systemctl restart docker
    else
        local ORIGINAL_CONFIG=$(cat "$CONFIG_FILE")
        local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')
        local UPDATED_CONFIG
        if [ "$CURRENT_IPV6" = "false" ]; then
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
        else
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
        fi
        if [ "$ORIGINAL_CONFIG" = "$UPDATED_CONFIG" ]; then
            echo -e "${YELLOW}当前已开启IPv6${RESET}"
        else
            echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
            if systemctl restart docker; then
                echo -e "${GREEN}Docker IPv6开启成功${RESET}"
            else
                echo -e "${RED}Docker IPv6开启失败${RESET}"
            fi
        fi
    fi
    press_any_key
}

docker_ipv6_off() {
    echo -e "${GREEN}开始关闭Docker IPv6...${RESET}"
    if ! check_command jq; then
        if [ -f /etc/redhat-release ]; then
            yum install -y jq
        else
            apt install -y jq
        fi
    fi
    local CONFIG_FILE="/etc/docker/daemon.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Docker配置文件不存在${RESET}"
        press_any_key
        return
    fi
    local ORIGINAL_CONFIG=$(cat "$CONFIG_FILE")
    local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')
    local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')
    if [ "$CURRENT_IPV6" = "false" ]; then
        echo -e "${YELLOW}当前已关闭IPv6${RESET}"
    else
        echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
        if systemctl restart docker; then
            echo -e "${GREEN}Docker IPv6关闭成功${RESET}"
        else
            echo -e "${RED}Docker IPv6关闭失败${RESET}"
        fi
    fi
    press_any_key
}

# ========================
# 系统设置
# ========================
system_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 系统设置 ==="
        echo -e "1. 清理系统"
        echo -e "2. 网络优化"
        echo -e "3. 时区设置"
        echo -e "4. 虚拟内存设置"
        echo -e "5. SSH防御"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) clean_system ;;
            2) optimize_network ;;
            3) set_timezone ;;
            4) set_swap ;;
            5) ssh_defense ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

setup_alias() {
    show_banner
    echo -e "${GREEN}=== 设置快捷键 ==="
    echo -e "${YELLOW}当前快捷命令: skywrt${RESET}"
    
    read -p "输入新的快捷命令 (留空保持当前): " alias_name
    if [ -z "$alias_name" ]; then
        return
    fi
    
    echo "alias $alias_name='bash <(curl -sL ${DOMAIN})'" >> ~/.bashrc
    if source ~/.bashrc; then
        echo -e "${GREEN}快捷命令 $alias_name 设置成功${RESET}"
        echo -e "现在可以使用: ${BLUE}$alias_name${RESET} 启动脚本"
    else
        echo -e "${RED}快捷命令设置失败${RESET}"
    fi
    press_any_key
}

clean_system() {
    echo -e "${GREEN}开始清理系统...${RESET}"
    if [ -f /etc/redhat-release ]; then
        yum autoremove -y
        yum clean all
    else
        apt autoremove -y
        apt autoclean
    fi
    rm -rf /tmp/*
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}系统清理成功${RESET}"
    else
        echo -e "${RED}系统清理失败${RESET}"
    fi
    press_any_key
}

optimize_network() {
    echo -e "${GREEN}开始优化网络设置...${RESET}"
    cat > /etc/sysctl.d/99-skywrt.conf << EOF
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
EOF
    if sysctl -p /etc/sysctl.d/99-skywrt.conf; then
        echo -e "${GREEN}网络优化完成${RESET}"
    else
        echo -e "${RED}网络优化失败${RESET}"
    fi
    press_any_key
}

set_timezone() {
    show_banner
    echo -e "${GREEN}=== 时区设置 ==="
    echo -e "常用时区:"
    echo -e "1. Asia/Shanghai (中国标准时间)"
    echo -e "2. America/New_York"
    echo -e "3. Europe/London"
    echo -e "4. 自定义时区"
    echo -e "${BLUE}0. 返回上级${RESET}"
    
    read -p "请选择时区: " choice
    
    case $choice in
        1) timezone="Asia/Shanghai" ;;
        2) timezone="America/New_York" ;;
        3) timezone="Europe/London" ;;
        4) read -p "请输入时区 (如 Asia/Tokyo): " timezone ;;
        0) return ;;
        *) echo -e "${RED}无效选择!${RESET}"; sleep 1; return ;;
    esac
    
    echo -e "${GREEN}设置时区为 $timezone...${RESET}"
    if timedatectl set-timezone "$timezone"; then
        echo -e "${GREEN}时区设置成功${RESET}"
    else
        echo -e "${RED}时区设置失败${RESET}"
    fi
    press_any_key
}

set_swap() {
    show_banner
    echo -e "${GREEN}=== 虚拟内存设置 ==="
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    echo -e "当前虚拟内存: ${YELLOW}${swap_total}MB${RESET}"
    read -p "请输入新的虚拟内存大小(MB): " swap_size
    if [ -z "$swap_size" ]; then
        echo -e "${RED}请输入有效的大小${RESET}"
        press_any_key
        return
    fi
    
    echo -e "${GREEN}开始设置虚拟内存为 ${swap_size}MB...${RESET}"
    swapoff -a
    rm -f /swapfile
    fallocate -l "${swap_size}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}虚拟内存设置成功${RESET}"
    else
        echo -e "${RED}虚拟内存设置失败${RESET}"
    fi
    press_any_key
}

ssh_defense() {
    while true; do
        show_banner
        echo -e "${GREEN}=== SSH防御 ==="
        if check_command fail2ban-client; then
            echo -e "${YELLOW}Fail2Ban已安装${RESET}"
            echo -e "1. 查看SSH拦截记录"
            echo -e "2. 日志实时监控"
            echo -e "3. 卸载Fail2Ban"
        else
            echo -e "1. 安装Fail2Ban"
        fi
        echo -e "${BLUE}0. 返回上级${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                if check_command fail2ban-client; then
                    if fail2ban-client status sshd; then
                        echo -e "${GREEN}SSH拦截记录显示成功${RESET}"
                    else
                        echo -e "${RED}无法显示SSH拦截记录${RESET}"
                    fi
                else
                    install_fail2ban
                fi
                ;;
            2)
                if [ -f /var/log/fail2ban.log ]; then
                    tail -f /var/log/fail2ban.log
                else
                    echo -e "${RED}Fail2Ban日志文件不存在${RESET}"
                fi
                ;;
            3)
                if [ -f /etc/redhat-release ]; then
                    yum remove -y fail2ban
                else
                    apt remove -y fail2ban
                fi
                rm -rf /etc/fail2ban
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Fail2Ban卸载成功${RESET}"
                else
                    echo -e "${RED}Fail2Ban卸载失败${RESET}"
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

install_fail2ban() {
    echo -e "${GREEN}开始安装Fail2Ban...${RESET}"
    if [ -f /etc/redhat-release ]; then
        yum install -y epel-release
        yum install -y fail2ban
    else
        apt install -y fail2ban
    fi
    systemctl enable fail2ban
    systemctl start fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
EOF
    if systemctl restart fail2ban; then
        echo -e "${GREEN}Fail2Ban安装成功${RESET}"
    else
        echo -e "${RED}Fail2Ban安装失败${RESET}"
    fi
    press_any_key
}

# ========================
# 脚本更新
# ========================
update_script() {
    show_banner
    echo -e "${GREEN}=== 脚本更新 ==="
    local new_version
    new_version=$(curl -s "${DOMAIN}" | grep -o 'SH_VERSION="[0-9.]*"' | cut -d '"' -f 2)
    if [ -z "$new_version" ]; then
        new_version=$(curl -s "${FALLBACK_URL}" | grep -o 'SH_VERSION="[0-9.]*"' | cut -d '"' -f 2)
        if [ -z "$new_version" ]; then
            echo -e "${RED}无法获取最新版本，请检查网络${RESET}"
            press_any_key
            return
        fi
        update_url="${FALLBACK_URL}"
    else
        update_url="${DOMAIN}"
    fi
    if [ "$SH_VERSION" = "$new_version" ]; then
        echo -e "${YELLOW}当前已是最新版本: v$SH_VERSION${RESET}"
    else
        echo -e "当前版本: v$SH_VERSION  最新版本: ${GREEN}v$new_version${RESET}"
        read -p "是否更新到最新版本？(y/n): " confirm
        if [ "$confirm" = "y" ]; then
            if curl -sS -o /root/skywrt.sh "$update_url"; then
                chmod +x /root/skywrt.sh
                cp /root/skywrt.sh /usr/local/bin/skywrt
                echo -e "${GREEN}脚本已更新到 v$new_version${RESET}"
                exec /root/skywrt.sh
            else
                echo -e "${RED}脚本下载失败，请检查网络${RESET}"
            fi
        fi
    fi
    press_any_key
}

# ========================
# 脚本入口
# ========================
check_root
main_menu
