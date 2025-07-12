#!/bin/bash
# SkyWRT 全功能管理脚本
# 使用方式: bash <(curl -sL https://sink.ysx66.com/skywrt)
# 版本: 4.0.0

# ========================
# 颜色定义
# ========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ========================
# 全局变量
# ========================
SH_VERSION="4.0.0"
LOG_FILE="/var/log/skywrt.log"
ENABLE_STATS="true"
GH_PROXY="https://ghproxy.com/"

# ========================
# 日志设置
# ========================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

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
    echo -e "SkyWRT 管理脚本 v${SH_VERSION} | 项目: ${BLUE}https://github.com/skywrt/linux${RESET}"
    echo
}

# ========================
# 基础功能
# ========================
check_root() {
    [ "$(id -u)" -ne 0 ] && {
        log "${RED}错误: 此脚本需要root权限${RESET}"
        echo -e "请使用: ${BLUE}sudo bash <(curl -sL https://sink.ysx66.com/skywrt)${RESET}"
        exit 1
    }
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
    local available_space_mb=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        log "${YELLOW}警告: 磁盘空间不足！可用: $((available_space_mb/1024))G，需求: ${required_gb}G${RESET}"
        echo -e "${YELLOW}磁盘空间不足，无法继续！${RESET}"
        press_any_key
        exit 1
    fi
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
        echo -e "4. 系统设置"
        echo -e "5. 防火墙管理"
        echo -e "6. 服务器集群控制"
        echo -e "7. 系统备份与恢复"
        echo -e "8. 隐私与安全"
        echo -e "9. 脚本更新${RESET}"
        echo -e "${BLUE}0. 退出${RESET}"
        echo -e "========================="
        
        read -p "请输入选项: " choice
        
        case $choice in
            1) source_menu ;;
            2) software_menu ;;
            3) docker_menu ;;
            4) system_menu ;;
            5) firewall_menu ;;
            6) cluster_menu ;;
            7) backup_menu ;;
            8) privacy_menu ;;
            9) update_script ;;
            0) log "退出 SkyWRT 脚本"; exit 0 ;;
            *) echo -e "${RED}无效选项!${RESET}"; sleep 1 ;;
        esac
    done
}

# ========================
# 统计数据发送
# ========================
send_stats() {
    if [ "$ENABLE_STATS" == "false" ]; then
        return
    fi
    local country=$(curl -s ipinfo.io/country || echo "unknown")
    local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"' || echo "unknown")
    local cpu_arch=$(uname -m)
    (
        curl -s -X POST "https://api.skywrt.org/log" \
            -H "Content-Type: application/json" \
            -d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$SH_VERSION\"}" \
        &>/dev/null
    ) &
}

# ========================
# 系统换源
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
                send_stats "更换软件源"
                [ -f /etc/redhat-release ] && centos_source "$choice" || debian_source "$choice"
                press_any_key
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

centos_source() {
    local mirror
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.tencent.com" ;;
        3) mirror="mirrors.tuna.tsinghua.edu.cn" ;;
    esac
    
    log "开始配置 $mirror 源..."
    [ -d /etc/yum.repos.d ] || { log "${RED}Yum配置文件目录不存在${RESET}"; return 1; }
    
    mkdir -p /etc/yum.repos.d/backup
    cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org|baseurl=https://$mirror|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo
    yum makecache && {
        log "${GREEN}换源完成!${RESET}"
        echo -e "${GREEN}换源完成!${RESET}"
    } || {
        log "${RED}换源失败!${RESET}"
        echo -e "${RED}换源失败!${RESET}"
    }
}

debian_source() {
    local mirror
    case $1 in
        1) mirror="mirrors.aliyun.com" ;;
        2) mirror="mirrors.163.com" ;;
        3) mirror="repo.huaweicloud.com" ;;
    esac
    
    log "开始配置 $mirror 源..."
    [ -f /etc/apt/sources.list ] || { log "${RED}APT配置文件不存在${RESET}"; return 1; }
    
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sed -i "s|http://.*archive.ubuntu.com|https://$mirror|g" /etc/apt/sources.list
    apt update && {
        log "${GREEN}换源完成!${RESET}"
        echo -e "${GREEN}换源完成!${RESET}"
    } || {
        log "${RED}换源失败!${RESET}"
        echo -e "${RED}换源失败!${RESET}"
    }
}

# ========================
# 软件管理
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
            1) send_stats "安装开发工具"; install_dev_tools ;;
            2) send_stats "安装网络工具"; install_net_tools ;;
            3) send_stats "安装监控工具"; install_monitor_tools ;;
            4) send_stats "自定义安装"; custom_install ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_dev_tools() {
    log "开始安装开发工具..."
    if [ -f /etc/redhat-release ]; then
        yum groupinstall -y "Development Tools" && yum install -y vim nano
    else
        apt install -y build-essential vim nano
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}开发工具安装成功${RESET}"
        echo -e "${GREEN}开发工具安装成功${RESET}"
    } || {
        log "${RED}开发工具安装失败${RESET}"
        echo -e "${RED}开发工具安装失败${RESET}"
    }
    press_any_key
}

install_net_tools() {
    log "开始安装网络工具..."
    if [ -f /etc/redhat-release ]; then
        yum install -y net-tools curl wget nmap
    else
        apt install -y net-tools curl wget nmap
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}网络工具安装成功${RESET}"
        echo -e "${GREEN}网络工具安装成功${RESET}"
    } || {
        log "${RED}网络工具安装失败${RESET}"
        echo -e "${RED}网络工具安装失败${RESET}"
    }
    press_any_key
}

install_monitor_tools() {
    log "开始安装监控工具..."
    if [ -f /etc/redhat-release ]; then
        yum install -y htop iotop iftop
    else
        apt install -y htop iotop iftop
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}监控工具安装成功${RESET}"
        echo -e "${GREEN}监控工具安装成功${RESET}"
    } || {
        log "${RED}监控工具安装失败${RESET}"
        echo -e "${RED}监控工具安装失败${RESET}"
    }
    press_any_key
}

custom_install() {
    read -p "请输入要安装的软件包名称: " packages
    [ -z "$packages" ] && {
        echo -e "${RED}请输入有效的软件包名称${RESET}"
        press_any_key
        return
    }
    
    log "开始安装自定义软件包: $packages..."
    if [ -f /etc/redhat-release ]; then
        yum install -y $packages
    else
        apt install -y $packages
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}自定义软件包安装成功${RESET}"
        echo -e "${GREEN}自定义软件包安装成功${RESET}"
    } || {
        log "${RED}自定义软件包安装失败${RESET}"
        echo -e "${RED}自定义软件包安装失败${RESET}"
    }
    press_any_key
}

remove_software() {
    read -p "请输入要卸载的软件包名称: " packages
    [ -z "$packages" ] && {
        echo -e "${RED}请输入有效的软件包名称${RESET}"
        press_any_key
        return
    }
    
    log "开始卸载软件包: $packages..."
    if [ -f /etc/redhat-release ]; then
        yum remove -y $packages
    else
        apt remove -y $packages
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}软件包卸载成功${RESET}"
        echo -e "${GREEN}软件包卸载成功${RESET}"
    } || {
        log "${RED}软件包卸载失败${RESET}"
        echo -e "${RED}软件包卸载失败${RESET}"
    }
    press_any_key
}

update_packages() {
    log "开始更新软件列表..."
    if [ -f /etc/redhat-release ]; then
        yum makecache
    else
        apt update
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}软件列表更新成功${RESET}"
        echo -e "${GREEN}软件列表更新成功${RESET}"
    } || {
        log "${RED}软件列表更新失败${RESET}"
        echo -e "${RED}软件列表更新失败${RESET}"
    }
    press_any_key
}

upgrade_system() {
    log "开始系统升级..."
    if [ -f /etc/redhat-release ]; then
        yum upgrade -y
    else
        apt upgrade -y
    fi
    [ $? -eq 0 ] && {
        log "${GREEN}系统升级成功${RESET}"
        echo -e "${GREEN}系统升级成功${RESET}"
    } || {
        log "${RED}系统升级失败${RESET}"
        echo -e "${RED}系统升级失败${RESET}"
    }
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
            1) send_stats "安装Docker"; install_docker ;;
            2) send_stats "配置Docker镜像加速"; config_docker ;;
            3) send_stats "容器管理"; docker_ps ;;
            4) send_stats "镜像管理"; docker_image ;;
            5) send_stats "卸载Docker"; remove_docker ;;
            6) docker_ipv6_menu ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

install_docker() {
    log "开始安装Docker..."
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
    systemctl enable docker
    systemctl start docker
    if [ $? -eq 0 ]; then
        log "${GREEN}Docker安装成功${RESET}"
        echo -e "${GREEN}Docker安装成功${RESET}"
    else
        log "${RED}Docker安装失败${RESET}"
        echo -e "${RED}Docker安装失败${RESET}"
    fi
    press_any_key
}

config_docker() {
    log "开始配置Docker镜像加速..."
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
    systemctl restart docker
    [ $? -eq 0 ] && {
        log "${GREEN}Docker镜像加速配置成功${RESET}"
        echo -e "${GREEN}Docker镜像加速配置成功${RESET}"
    } || {
        log "${RED}Docker镜像加速配置失败${RESET}"
        echo -e "${RED}Docker镜像加速配置失败${RESET}"
    }
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
                eval "$docker_cmd" && log "容器创建成功"
                ;;
            2)
                read -p "请输入容器名或ID: " container
                docker start "$container" && log "容器 $container 启动成功"
                ;;
            3)
                read -p "请输入容器名或ID: " container
                docker stop "$container" && log "容器 $container 停止成功"
                ;;
            4)
                read -p "请输入容器名或ID: " container
                docker rm -f "$container" && log "容器 $container 删除成功"
                ;;
            5)
                read -p "请输入容器名或ID: " container
                docker restart "$container" && log "容器 $container 重启成功"
                ;;
            6)
                docker start $(docker ps -a -q) && log "所有容器启动成功"
                ;;
            7)
                docker stop $(docker ps -q) && log "所有容器停止成功"
                ;;
            8)
                read -p "确认删除所有容器？(y/n): " confirm
                [ "$confirm" = "y" ] && docker rm -f $(docker ps -a -q) && log "所有容器删除成功"
                ;;
            9)
                read -p "请输入容器名或ID: " container
                docker exec -it "$container" /bin/sh
                ;;
            10)
                read -p "请输入容器名或ID: " container
                docker logs "$container"
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
                docker pull "$image" && log "镜像 $image 拉取成功"
                ;;
            2)
                read -p "请输入镜像名: " image
                docker pull "$image" && log "镜像 $image 更新成功"
                ;;
            3)
                read -p "请输入镜像名: " image
                docker rmi -f "$image" && log "镜像 $image 删除成功"
                ;;
            4)
                read -p "确认删除所有镜像？(y/n): " confirm
                [ "$confirm" = "y" ] && docker rmi -f $(docker images -q) && log "所有镜像删除成功"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

remove_docker() {
    log "开始卸载Docker..."
    if [ -f /etc/redhat-release ]; then
        yum remove -y docker docker-ce
    else
        apt remove -y docker docker.io containerd runc
    fi
    rm -rf /var/lib/docker
    [ $? -eq 0 ] && {
        log "${GREEN}Docker卸载成功${RESET}"
        echo -e "${GREEN}Docker卸载成功${RESET}"
    } || {
        log "${RED}Docker卸载失败${RESET}"
        echo -e "${RED}Docker卸载失败${RESET}"
    }
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
            1) send_stats "开启Docker IPv6"; docker_ipv6_on ;;
            2) send_stats "关闭Docker IPv6"; docker_ipv6_off ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

docker_ipv6_on() {
    log "开始配置Docker IPv6..."
    check_command jq || {
        if [ -f /etc/redhat-release ]; then
            yum install -y jq
        else
            apt install -y jq
        fi
    }
    local CONFIG_FILE="/etc/docker/daemon.json"
    local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$REQUIRED_IPV6_CONFIG" | jq . > "$CONFIG_FILE"
        systemctl restart docker
    else
        local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")
        local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')
        local UPDATED_CONFIG
        if [[ "$CURRENT_IPV6" == "false" ]]; then
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
        else
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
        fi
        if [[ "$ORIGINAL_CONFIG" == "$UPDATED_CONFIG" ]]; then
            echo -e "${YELLOW}当前已开启IPv6${RESET}"
        else
            echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
            systemctl restart docker
            log "${GREEN}Docker IPv6开启成功${RESET}"
            echo -e "${GREEN}Docker IPv6开启成功${RESET}"
        fi
    fi
    press_any_key
}

docker_ipv6_off() {
    log "开始关闭Docker IPv6..."
    check_command jq || {
        if [ -f /etc/redhat-release ]; then
            yum install -y jq
        else
            apt install -y jq
        fi
    }
    local CONFIG_FILE="/etc/docker/daemon.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Docker配置文件不存在${RESET}"
        press_any_key
        return
    fi
    local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")
    local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')
    local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')
    if [[ "$CURRENT_IPV6" == "false" ]]; then
        echo -e "${YELLOW}当前已关闭IPv6${RESET}"
    else
        echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
        systemctl restart docker
        log "${GREEN}Docker IPv6关闭成功${RESET}"
        echo -e "${GREEN}Docker IPv6关闭成功${RESET}"
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
        echo -e "1. 设置命令别名"
        echo -e "2. 清理系统"
        echo -e "3. 网络优化"
        echo -e "4. 时区设置"
        echo -e "5. 虚拟内存设置"
        echo -e "6. SSH防御"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) send_stats "设置命令别名"; setup_alias ;;
            2) send_stats "清理系统"; clean_system ;;
            3) send_stats "网络优化"; optimize_network ;;
            4) send_stats "时区设置"; set_timezone ;;
            5) send_stats "虚拟内存设置"; set_swap ;;
            6) send_stats "SSH防御"; ssh_defense ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

setup_alias() {
    show_banner
    echo -e "${GREEN}=== 设置命令别名 ==="
    echo -e "${YELLOW}当前快捷命令: skywrt${RESET}"
    
    read -p "输入新的快捷命令 (留空保持当前): " alias_name
    [ -z "$alias_name" ] && return
    
    echo "alias $alias_name='bash <(curl -sL https://sink.ysx66.com/skywrt)'" >> ~/.bashrc
    source ~/.bashrc
    
    log "${GREEN}快捷命令 $alias_name 设置成功${RESET}"
    echo -e "${GREEN}快捷命令设置成功!${RESET}"
    echo -e "现在可以使用: ${BLUE}$alias_name${RESET} 启动脚本"
    press_any_key
}

clean_system() {
    log "开始清理系统..."
    if [ -f /etc/redhat-release ]; then
        yum autoremove -y
        yum clean all
    else
        apt autoremove -y
        apt autoclean
    fi
    rm -rf /tmp/*
    [ $? -eq 0 ] && {
        log "${GREEN}系统清理成功${RESET}"
        echo -e "${GREEN}系统清理成功${RESET}"
    } || {
        log "${RED}系统清理失败${RESET}"
        echo -e "${RED}系统清理失败${RESET}"
    }
    press_any_key
}

optimize_network() {
    log "开始优化网络设置..."
    cat > /etc/sysctl.d/99-skywrt.conf << EOF
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
EOF
    sysctl -p /etc/sysctl.d/99-skywrt.conf
    [ $? -eq 0 ] && {
        log "${GREEN}网络优化完成${RESET}"
        echo -e "${GREEN}网络优化完成${RESET}"
    } || {
        log "${RED}网络优化失败${RESET}"
        echo -e "${RED}网络优化失败${RESET}"
    }
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
    
    log "设置时区为 $timezone..."
    timedatectl set-timezone "$timezone"
    [ $? -eq 0 ] && {
        log "${GREEN}时区设置成功${RESET}"
        echo -e "${GREEN}时区设置成功${RESET}"
    } || {
        log "${RED}时区设置失败${RESET}"
        echo -e "${RED}时区设置失败${RESET}"
    }
    press_any_key
}

set_swap() {
    show_banner
    echo -e "${GREEN}=== 虚拟内存设置 ==="
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    echo -e "当前虚拟内存: ${YELLOW}${swap_total}MB${RESET}"
    read -p "请输入新的虚拟内存大小(MB): " swap_size
    [ -z "$swap_size" ] && {
        echo -e "${RED}请输入有效的大小${RESET}"
        press_any_key
        return
    }
    
    log "开始设置虚拟内存为 ${swap_size}MB..."
    swapoff -a
    rm -f /swapfile
    fallocate -l "${swap_size}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    [ $? -eq 0 ] && {
        log "${GREEN}虚拟内存设置成功${RESET}"
        echo -e "${GREEN}虚拟内存设置成功${RESET}"
    } || {
        log "${RED}虚拟内存设置失败${RESET}"
        echo -e "${RED}虚拟内存设置失败${RESET}"
    }
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
                    fail2ban-client status sshd
                else
                    send_stats "安装Fail2Ban"
                    install_fail2ban
                fi
                ;;
            2)
                send_stats "Fail2Ban日志监控"
                tail -f /var/log/fail2ban.log
                ;;
            3)
                send_stats "卸载Fail2Ban"
                if [ -f /etc/redhat-release ]; then
                    yum remove -y fail2ban
                else
                    apt remove -y fail2ban
                fi
                rm -rf /etc/fail2ban
                log "${GREEN}Fail2Ban卸载成功${RESET}"
                echo -e "${GREEN}Fail2Ban卸载成功${RESET}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

install_fail2ban() {
    log "开始安装Fail2Ban..."
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
    systemctl restart fail2ban
    [ $? -eq 0 ] && {
        log "${GREEN}Fail2Ban安装成功${RESET}"
        echo -e "${GREEN}Fail2Ban安装成功${RESET}"
    } || {
        log "${RED}Fail2Ban安装失败${RESET}"
        echo -e "${RED}Fail2Ban安装失败${RESET}"
    }
    press_any_key
}

# ========================
# 防火墙管理
# ========================
firewall_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 防火墙管理 ==="
        iptables -L INPUT
        echo -e "------------------------"
        echo -e "1. 开放指定端口"
        echo -e "2. 关闭指定端口"
        echo -e "3. 开放所有端口"
        echo -e "4. 关闭所有端口"
        echo -e "5. IP白名单"
        echo -e "6. IP黑名单"
        echo -e "7. 清除指定IP"
        echo -e "8. 允许PING"
        echo -e "9. 禁止PING"
        echo -e "10. 开启DDoS防御"
        echo -e "11. 关闭DDoS防御"
        echo -e "12. 阻止指定国家IP"
        echo -e "13. 仅允许指定国家IP"
        echo -e "14. 解除指定国家IP限制"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) send_stats "开放端口"; read -p "请输入端口号: " port; open_port "$port" ;;
            2) send_stats "关闭端口"; read -p "请输入端口号: " port; close_port "$port" ;;
            3) send_stats "开放所有端口"; iptables_open ;;
            4) send_stats "关闭所有端口"; iptables_close ;;
            5) send_stats "IP白名单"; read -p "请输入IP或IP段: " ip; allow_ip "$ip" ;;
            6) send_stats "IP黑名单"; read -p "请输入IP或IP段: " ip; block_ip "$ip" ;;
            7) send_stats "清除IP"; read -p "请输入IP: " ip; clear_ip "$ip" ;;
            8) send_stats "允许PING"; allow_ping ;;
            9) send_stats "禁止PING"; disable_ping ;;
            10) send_stats "开启DDoS防御"; enable_ddos_defense ;;
            11) send_stats "关闭DDoS防御"; disable_ddos_defense ;;
            12) send_stats "阻止国家IP"; read -p "请输入国家代码（如CN, US）: " code; manage_country_rules block "$code" ;;
            13) send_stats "仅允许国家IP"; read -p "请输入国家代码（如CN, US）: " code; manage_country_rules allow "$code" ;;
            14) send_stats "解除国家IP限制"; read -p "请输入国家代码（如CN, US）: " code; manage_country_rules unblock "$code" ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

save_iptables_rules() {
    mkdir -p /etc/iptables
    touch /etc/iptables/rules.v4
    iptables-save > /etc/iptables/rules.v4
    check_command crontab || {
        if [ -f /etc/redhat-release ]; then
            yum install -y cronie
            systemctl enable crond
            systemctl start crond
        else
            apt install -y cron
            systemctl enable cron
            systemctl start cron
        fi
    }
    crontab -l | grep -v 'iptables-restore' | crontab - >/dev/null 2>&1
    (crontab -l ; echo '@reboot iptables-restore < /etc/iptables/rules.v4') | crontab - >/dev/null 2>&1
}

iptables_open() {
    log "开放所有端口..."
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    local ssh_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}' || echo 22)
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A FORWARD -i lo -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
    save_iptables_rules
    log "${GREEN}所有端口已开放${RESET}"
    echo -e "${GREEN}所有端口已开放${RESET}"
}

iptables_close() {
    log "关闭所有端口..."
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    local ssh_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}' || echo 22)
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A FORWARD -i lo -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
    save_iptables_rules
    log "${GREEN}所有端口已关闭${RESET}"
    echo -e "${GREEN}所有端口已关闭${RESET}"
}

open_port() {
    local ports=($@)
    [ ${#ports[@]} -eq 0 ] && {
        echo -e "${RED}请提供至少一个端口号${RESET}"
        return 1
    }
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    for port in "${ports[@]}"; do
        iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
        iptables -D INPUT -p udp --dport "$port" -j DROP 2>/dev/null
        if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
        fi
        if ! iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport "$port" -j ACCEPT
            log "端口 $port 已开放"
            echo -e "${GREEN}端口 $port 已开放${RESET}"
        fi
    done
    save_iptables_rules
}

close_port() {
    local ports=($@)
    [ ${#ports[@]} -eq 0 ] && {
        echo -e "${RED}请提供至少一个端口号${RESET}"
        return 1
    }
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    for port in "${ports[@]}"; do
        iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null
        if ! iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport "$port" -j DROP
        fi
        if ! iptables -C INPUT -p udp --dport "$port" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport "$port" -j DROP
            log "端口 $port 已关闭"
            echo -e "${GREEN}端口 $port 已关闭${RESET}"
        fi
    done
    save_iptables_rules
}

allow_ip() {
    local ips=($@)
    [ ${#ips[@]} -eq 0 ] && {
        echo -e "${RED}请提供至少一个IP地址或IP段${RESET}"
        return 1
    }
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    for ip in "${ips[@]}"; do
        iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
        if ! iptables -C INPUT -s "$ip" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -s "$ip" -j ACCEPT
            log "IP $ip 已加入白名单"
            echo -e "${GREEN}IP $ip 已加入白名单${RESET}"
        fi
    done
    save_iptables_rules
}

block_ip() {
    local ips=($@)
    [ ${#ips[@]} -eq 0 ] && {
        echo -e "${RED}请提供至少一个IP地址或IP段${RESET}"
        return 1
    }
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    for ip in "${ips[@]}"; do
        iptables -D INPUT -s "$ip" -j ACCEPT 2>/dev/null
        if ! iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -s "$ip" -j DROP
            log "IP $ip 已加入黑名单"
            echo -e "${GREEN}IP $ip 已加入黑名单${RESET}"
        fi
    done
    save_iptables_rules
}

clear_ip() {
    local ip="$1"
    [ -z "$ip" ] && {
        echo -e "${RED}请输入有效的IP地址${RESET}"
        return 1
    }
    iptables -D INPUT -s "$ip" -j ACCEPT 2>/dev/null
    iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
    save_iptables_rules
    log "IP $ip 已从规则中清除"
    echo -e "${GREEN}IP $ip 已从规则中清除${RESET}"
}

allow_ping() {
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
    save_iptables_rules
    log "${GREEN}PING已启用${RESET}"
    echo -e "${GREEN}PING已启用${RESET}"
}

disable_ping() {
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null
    iptables -D OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT 2>/dev/null
    save_iptables_rules
    log "${GREEN}PING已禁用${RESET}"
    echo -e "${GREEN}PING已禁用${RESET}"
}

enable_ddos_defense() {
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    iptables -A DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A DOCKER-USER -p tcp --syn -j DROP
    iptables -A DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A DOCKER-USER -p udp -j DROP
    iptables -A INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    iptables -A INPUT -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A INPUT -p udp -j DROP
    save_iptables_rules
    log "${GREEN}DDoS防御已启用${RESET}"
    echo -e "${GREEN}DDoS防御已启用${RESET}"
}

disable_ddos_defense() {
    check_command iptables || {
        if [ -f /etc/redhat-release ]; then
            yum install -y iptables
        else
            apt install -y iptables
        fi
    }
    iptables -D DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p tcp --syn -j DROP 2>/dev/null
    iptables -D DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p udp -j DROP 2>/dev/null
    iptables -D INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --syn -j DROP 2>/dev/null
    iptables -D INPUT -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp -j DROP 2>/dev/null
    save_iptables_rules
    log "${GREEN}DDoS防御已禁用${RESET}"
    echo -e "${GREEN}DDoS防御已禁用${RESET}"
}

manage_country_rules() {
    local action="$1"
    local country_code="$2"
    local ipset_name="${country_code,,}_block"
    local download_url="http://www.ipdeny.com/ipblocks/data/countries/${country_code,,}.zone"
    
    check_command ipset || {
        if [ -f /etc/redhat-release ]; then
            yum install -y ipset
        else
            apt install -y ipset
        fi
    }
    
    case "$action" in
        block)
            if ! ipset list "$ipset_name" &>/dev/null; then
                ipset create "$ipset_name" hash:net
            fi
            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                log "${RED}下载 $country_code IP区域文件失败${RESET}"
                echo -e "${RED}下载 $country_code IP区域文件失败${RESET}"
                return 1
            fi
            while IFS= read -r ip; do
                ipset add "$ipset_name" "$ip"
            done < "${country_code,,}.zone"
            iptables -I INPUT -m set --match-set "$ipset_name" src -j DROP
            iptables -I OUTPUT -m set --match-set "$ipset_name" dst -j DROP
            save_iptables_rules
            log "${GREEN}已阻止 $country_code IP${RESET}"
            echo -e "${GREEN}已阻止 $country_code IP${RESET}"
            rm "${country_code,,}.zone"
            ;;
        allow)
            if ! ipset list "$ipset_name" &>/dev/null; then
                ipset create "$ipset_name" hash:net
            fi
            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                log "${RED}下载 $country_code IP区域文件失败${RESET}"
                echo -e "${RED}下载 $country_code IP区域文件失败${RESET}"
                return 1
            fi
            iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null
            iptables -D OUTPUT -m set --match-set "$ipset_name" dst -j DROP 2>/dev/null
            ipset flush "$ipset_name"
            while IFS= read -r ip; do
                ipset add "$ipset_name" "$ip"
            done < "${country_code,,}.zone"
            iptables -P INPUT DROP
            iptables -P OUTPUT DROP
            iptables -A INPUT -m set --match-set "$ipset_name" src -j ACCEPT
            iptables -A OUTPUT -m set --match-set "$ipset_name" dst -j ACCEPT
            save_iptables_rules
            log "${GREEN}已仅允许 $country_code IP${RESET}"
            echo -e "${GREEN}已仅允许 $country_code IP${RESET}"
            rm "${country_code,,}.zone"
            ;;
        unblock)
            iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null
            iptables -D OUTPUT -m set --match-set "$ipset_name" dst -j DROP 2>/dev/null
            if ipset list "$ipset_name" &>/dev/null; then
                ipset destroy "$ipset_name"
            fi
            save_iptables_rules
            log "${GREEN}已解除 $country_code IP限制${RESET}"
            echo -e "${GREEN}已解除 $country_code IP限制${RESET}"
            ;;
        *)
            echo -e "${RED}无效操作${RESET}"
            ;;
    esac
}

# ========================
# 服务器集群控制
# ========================
cluster_menu() {
    mkdir -p ~/cluster
    if [ ! -f ~/cluster/servers.sh ]; then
        cat > ~/cluster/servers.sh << EOF
SERVERS=(
    # 格式: "name|hostname|port|username|password"
    # 示例: "server1|192.168.1.1|22|root|password"
)
EOF
    fi
    
    while true; do
        show_banner
        echo -e "${GREEN}=== 服务器集群控制 ==="
        cat ~/cluster/servers.sh
        echo -e "------------------------"
        echo -e "1. 添加服务器"
        echo -e "2. 删除服务器"
        echo -e "3. 编辑服务器"
        echo -e "4. 批量执行命令"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) send_stats "添加集群服务器"; add_server ;;
            2) send_stats "删除集群服务器"; delete_server ;;
            3) send_stats "编辑集群服务器"; edit_server ;;
            4) send_stats "批量执行命令"; execute_cluster_command ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

add_server() {
    read -p "服务器名称: " server_name
    read -p "服务器IP: " server_ip
    read -p "服务器端口（默认22）: " server_port
    server_port=${server_port:-22}
    read -p "服务器用户名（默认root）: " server_username
    server_username=${server_username:-root}
    read -p "服务器密码: " server_password
    echo "\"$server_name|$server_ip|$server_port|$server_username|$server_password\"" >> ~/cluster/servers.sh
    log "${GREEN}服务器 $server_name 添加成功${RESET}"
    echo -e "${GREEN}服务器 $server_name 添加成功${RESET}"
    press_any_key
}

delete_server() {
    read -p "请输入要删除的服务器名称或IP: " keyword
    sed -i "/$keyword/d" ~/cluster/servers.sh
    log "${GREEN}服务器 $keyword 删除成功${RESET}"
    echo -e "${GREEN}服务器 $keyword 删除成功${RESET}"
    press_any_key
}

edit_server() {
    check_command nano || {
        if [ -f /etc/redhat-release ]; then
            yum install -y nano
        else
            apt install -y nano
        fi
    }
    nano ~/cluster/servers.sh
    log "${GREEN}服务器列表编辑完成${RESET}"
    echo -e "${GREEN}服务器列表编辑完成${RESET}"
    press_any_key
}

execute_cluster_command() {
    check_command sshpass || {
        if [ -f /etc/redhat-release ]; then
            yum install -y sshpass
        else
            apt install -y sshpass
        fi
    }
    read -p "请输入要执行的命令: " cmd
    source ~/cluster/servers.sh
    for server in "${SERVERS[@]}"; do
        IFS='|' read -r name hostname port username password <<< "$server"
        echo -e "${YELLOW}正在 $name ($hostname) 上执行命令...${RESET}"
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$hostname" -p "$port" "$cmd"
    done
    log "${GREEN}集群命令执行完成${RESET}"
    echo -e "${GREEN}集群命令执行完成${RESET}"
    press_any_key
}

# ========================
# 系统备份与恢复
# ========================
backup_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 系统备份与恢复 ==="
        echo -e "1. 创建系统备份"
        echo -e "2. 恢复系统备份"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1) send_stats "创建系统备份"; create_backup ;;
            2) send_stats "恢复系统备份"; restore_backup ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
    done
}

create_backup() {
    check_disk_space 5
    local backup_dir="/root/backup"
    local backup_file="system_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$backup_dir"
    log "开始创建系统备份..."
    tar -czf "$backup_dir/$backup_file" /etc /home /root
    [ $? -eq 0 ] && {
        log "${GREEN}系统备份创建成功: $backup_dir/$backup_file${RESET}"
        echo -e "${GREEN}系统备份创建成功: $backup_dir/$backup_file${RESET}"
    } || {
        log "${RED}系统备份创建失败${RESET}"
        echo -e "${RED}系统备份创建失败${RESET}"
    }
    press_any_key
}

restore_backup() {
    local backup_dir="/root/backup"
    ls -l "$backup_dir"
    read -p "请输入要恢复的备份文件名: " backup_file
    [ ! -f "$backup_dir/$backup_file" ] && {
        log "${RED}备份文件不存在${RESET}"
        echo -e "${RED}备份文件不存在${RESET}"
        press_any_key
        return
    }
    log "开始恢复系统备份 $backup_file..."
    tar -xzf "$backup_dir/$backup_file" -C /
    [ $? -eq 0 ] && {
        log "${GREEN}系统备份恢复成功${RESET}"
        echo -e "${GREEN}系统备份恢复成功${RESET}"
    } || {
        log "${RED}系统备份恢复失败${RESET}"
        echo -e "${RED}系统备份恢复失败${RESET}"
    }
    press_any_key
}

# ========================
# 隐私与安全
# ========================
privacy_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}=== 隐私与安全 ==="
        if [ "$ENABLE_STATS" == "true" ]; then
            echo -e "${YELLOW}当前状态: 数据采集已开启${RESET}"
        else
            echo -e "${CYAN}当前状态: 数据采集已关闭${RESET}"
        fi
        echo -e "1. 开启数据采集"
        echo -e "2. 关闭数据采集"
        echo -e "${BLUE}0. 返回主菜单${RESET}"
        echo -e "========================="
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                send_stats "开启数据采集"
                sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' "$0"
                ENABLE_STATS="true"
                log "${GREEN}数据采集已开启${RESET}"
                echo -e "${GREEN}数据采集已开启${RESET}"
                ;;
            2)
                send_stats "关闭数据采集"
                sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' "$0"
                ENABLE_STATS="false"
                log "${GREEN}数据采集已关闭${RESET}"
                echo -e "${GREEN}数据采集已关闭${RESET}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择!${RESET}"; sleep 1 ;;
        esac
        press_any_key
    done
}

# ========================
# 脚本更新
# ========================
update_script() {
    show_banner
    echo -e "${GREEN}=== 脚本更新 ==="
    local new_version=$(curl -s "${GH_PROXY}raw.githubusercontent.com/skywrt/linux/main/skywrt.sh" | grep -o 'SH_VERSION="[0-9.]*"' | cut -d '"' -f 2)
    if [ "$SH_VERSION" = "$new_version" ]; then
        echo -e "${YELLOW}当前已是最新版本: v$SH_VERSION${RESET}"
    else
        echo -e "当前版本: v$SH_VERSION  最新版本: ${GREEN}v$new_version${RESET}"
        read -p "是否更新到最新版本？(y/n): " confirm
        if [ "$confirm" = "y" ]; then
            curl -sS -o /root/skywrt.sh "${GH_PROXY}raw.githubusercontent.com/skywrt/linux/main/skywrt.sh"
            chmod +x /root/skywrt.sh
            cp /root/skywrt.sh /usr/local/bin/skywrt
            log "${GREEN}脚本已更新到 v$new_version${RESET}"
            echo -e "${GREEN}脚本已更新到 v$new_version${RESET}"
            exec /root/skywrt.sh
        fi
    fi
    press_any_key
}

# ========================
# 脚本入口
# ========================
check_root
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
log "SkyWRT 脚本启动"
main_menu
