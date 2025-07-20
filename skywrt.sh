#!/bin/bash
# SkyWRT Linux 管理脚本
# 使用方式: bash <(curl -fsSL https://sink.ysx66.com/linux)
# 版本: 2.4.1
# 说明: 支持系统换源、安装常用工具、Docker管理、系统设置、快捷键设置和脚本更新

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
SH_VERSION="2.4.1"
PERMISSION_GRANTED="false"
ENABLE_STATS="true"

# ========================
# Banner 显示
# ========================
show_banner() {
    clear
    echo -e "${CYAN}=============================================${RESET}"
    echo -e "${CYAN}        SkyWRT Linux 管理脚本 v$SH_VERSION        ${RESET}"
    echo -e "${CYAN}=============================================${RESET}"
    echo -e "${YELLOW}使用方式: bash <(curl -fsSL $DOMAIN)${RESET}"
    echo -e "${YELLOW}支持: 系统换源 | 工具安装 | Docker管理 | 脚本更新${RESET}"
    echo ""
}

# ========================
# 检查 root 权限
# ========================
root_use() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 该功能需要 root 权限，请以 root 用户或使用 sudo 执行！${RESET}"
        exit 1
    fi
}

# ========================
# 统计数据发送函数
# ========================
send_stats() {
    if [ "$ENABLE_STATS" == "false" ]; then
        return
    fi

    local country=$(curl -s ipinfo.io/country || echo "unknown")
    local os_info=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d '=' -f2 | tr -d '"' || echo "unknown")
    local cpu_arch=$(uname -m)

    (
        curl -s -X POST "https://api.skywrt.pro/log" \
            -H "Content-Type: application/json" \
            -d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$SH_VERSION\"}" \
            &>/dev/null
    ) &
}

# ========================
# 用户许可协议
# ========================
UserLicenseAgreement() {
    clear
    echo -e "${CYAN}欢迎使用 SkyWRT Linux 管理脚本${RESET}"
    echo "首次使用脚本，请先阅读并同意用户许可协议。"
    echo "用户许可协议: https://skywrt.pro/user-license-agreement/"
    echo -e "----------------------"
    read -r -p "是否同意以上条款？(y/n): " user_input

    if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
        send_stats "许可同意"
        sed -i 's/^PERMISSION_GRANTED="false"/PERMISSION_GRANTED="true"/' ~/skywrt.sh 2>/dev/null
        if [ -f /usr/local/bin/sw ]; then
            sed -i 's/^PERMISSION_GRANTED="false"/PERMISSION_GRANTED="true"/' /usr/local/bin/sw 2>/dev/null
        fi
    else
        send_stats "许可拒绝"
        clear
        exit
    fi
}

# ========================
# 检查首次运行
# ========================
CheckFirstRun() {
    if [ ! -f /usr/local/bin/sw ] || grep -q '^PERMISSION_GRANTED="false"' /usr/local/bin/sw 2>/dev/null; then
        UserLicenseAgreement
    fi
}

# ========================
# 安装软件包
# ========================
install() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}未提供软件包参数!${RESET}"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${YELLOW}正在安装 $package...${RESET}"
            if command -v dnf &>/dev/null; then
                dnf -y update
                dnf install -y epel-release
                dnf install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update
                yum install -y epel-release
                yum install -y "$package"
            elif command -v apt &>/dev/null; then
                apt update -y
                apt install -y "$package"
            elif command -v apk &>/dev/null; then
                apk update
                apk add "$package"
            elif command -v pacman &>/dev/null; then
                pacman -Syu --noconfirm
                pacman -S --noconfirm "$package"
            elif command -v zypper &>/dev/null; then
                zypper refresh
                zypper install -y "$package"
            elif command -v opkg &>/dev/null; then
                opkg update
                opkg install "$package"
            elif command -v pkg &>/dev/null; then
                pkg update
                pkg install -y "$package"
            else
                echo -e "${RED}未知的包管理器!${RESET}"
                return 1
            fi
        fi
    done
    send_stats "安装软件包: $@"
}

# ========================
# 系统换源
# ========================
change_repo() {
    root_use
    clear
    send_stats "系统换源"
    echo -e "${CYAN}系统换源管理${RESET}"
    echo "------------------------"
    echo "1. 使用默认源"
    echo "2. 使用阿里云源 (中国)"
    echo "3. 使用清华大学源 (中国)"
    echo "4. 使用 Ubuntu 默认源"
    echo "5. 使用 Debian 默认源"
    echo "------------------------"
    echo "0. 返回主菜单"
    echo "------------------------"
    read -e -p "请输入你的选择: " repo_choice

    case $repo_choice in
        1)
            echo -e "${YELLOW}恢复默认源...${RESET}"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
EOF
                        apt update
                        echo -e "${GREEN}已恢复 Ubuntu 默认源${RESET}"
                        ;;
                    debian)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian $VERSION_CODENAME main contrib non-free
deb http://deb.debian.org/debian $VERSION_CODENAME-updates main contrib non-free
deb http://deb.debian.org/debian-security $VERSION_CODENAME/updates main contrib non-free
EOF
                        apt update
                        echo -e "${GREEN}已恢复 Debian 默认源${RESET}"
                        ;;
                    centos|rhel|almalinux|rocky)
                        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null
                        dnf -y update
                        echo -e "${GREEN}已恢复 CentOS 默认源${RESET}"
                        ;;
                    *)
                        echo -e "${RED}不支持的发行版: $ID${RESET}"
                        ;;
                esac
            fi
            ;;
        2)
            echo -e "${YELLOW}切换到阿里云源...${RESET}"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
EOF
                        apt update
                        echo -e "${GREEN}已切换到阿里云 Ubuntu 源${RESET}"
                        ;;
                    debian)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/debian $VERSION_CODENAME main contrib non-free
deb http://mirrors.aliyun.com/debian $VERSION_CODENAME-updates main contrib non-free
deb http://mirrors.aliyun.com/debian-security $VERSION_CODENAME/updates main contrib non-free
EOF
                        apt update
                        echo -e "${GREEN}已切换到阿里云 Debian 源${RESET}"
                        ;;
                    centos|rhel|almalinux|rocky)
                        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null
                        curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-$VERSION_ID.repo
                        dnf -y update
                        echo -e "${GREEN}已切换到阿里云 CentOS 源${RESET}"
                        ;;
                    *)
                        echo -e "${RED}不支持的发行版: $ID${RESET}"
                        ;;
                esac
            fi
            ;;
        3)
            echo -e "${YELLOW}切换到清华大学源...${RESET}"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
EOF
                        apt update
                        echo -e "${GREEN}已切换到清华大学 Ubuntu 源${RESET}"
                        ;;
                    *)
                        echo -e "${RED}清华大学源仅支持 Ubuntu${RESET}"
                        ;;
                esac
            fi
            ;;
        4)
            echo -e "${YELLOW}切换到 Ubuntu 默认源...${RESET}"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
EOF
                        apt update
                        echo -e "${GREEN}已恢复 Ubuntu 默认源${RESET}"
                        ;;
                    *)
                        echo -e "${RED}仅支持 Ubuntu 的默认源恢复${RESET}"
                        ;;
                esac
            fi
            ;;
        5)
            echo -e "${YELLOW}切换到 Debian 默认源...${RESET}"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    debian)
                        cp /etc/apt/sources.list /etc/apt/sources.list.bak
                        cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian $VERSION_CODENAME main contrib non-free
deb http://deb.debian.org/debian $VERSION_CODENAME-updates main contrib non-free
deb http://deb.debian.org/debian-security $VERSION_CODENAME/updates main contrib non-free
EOF
                        apt update
                        echo -e "${GREEN}已恢复 Debian 默认源${RESET}"
                        ;;
                    *)
                        echo -e "${RED}仅支持 Debian 的默认源恢复${RESET}"
                        ;;
                esac
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择!${RESET}"
            ;;
    esac
    send_stats "换源操作: $repo_choice"
    break_end
}

# ========================
# 安装常用工具
# ========================
install_tools() {
    clear
    send_stats "安装常用工具"
    echo -e "${CYAN}安装常用工具${RESET}"
    echo "------------------------"
    echo "1. 安装基本工具 (wget, curl, nano, vim, htop)"
    echo "2. 安装开发工具 (git, python3, gcc, make)"
    echo "3. 安装网络工具 (net-tools, traceroute, nmap)"
    echo "------------------------"
    echo "0. 返回主菜单"
    echo "------------------------"
    read -e -p "请输入你的选择: " tool_choice

    case $tool_choice in
        1)
            install wget curl nano vim htop
            echo -e "${GREEN}基本工具已安装${RESET}"
            ;;
        2)
            install git python3 gcc make
            echo -e "${GREEN}开发工具已安装${RESET}"
            ;;
        3)
            install net-tools traceroute nmap
            echo -e "${GREEN}网络工具已安装${RESET}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择!${RESET}"
            ;;
    esac
    break_end
}

# ========================
# Docker 管理
# ========================
install_docker() {
    root_use
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}正在安装 Docker 环境...${RESET}"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    apt update
                    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
                    curl -fsSL https://download.docker.com/linux/$ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                    apt update
                    apt install -y docker-ce docker-ce-cli containerd.io
                    ;;
                centos|rhel|almalinux|rocky)
                    dnf -y update
                    dnf install -y yum-utils
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    dnf install -y docker-ce docker-ce-cli containerd.io
                    ;;
                *)
                    curl -fsSL https://get.docker.com | sh
                    ;;
            esac
            systemctl enable docker
            systemctl start docker
            echo -e "${GREEN}Docker 已安装并启动${RESET}"
        else
            echo -e "${RED}无法确定操作系统${RESET}"
            return 1
        fi
        send_stats "Docker 安装"
    else
        echo -e "${GREEN}Docker 已安装${RESET}"
    fi
    break_end
}

docker_manage() {
    clear
    send_stats "Docker 管理"
    echo -e "${CYAN}Docker 管理${RESET}"
    echo "------------------------"
    echo "1. 安装 Docker"
    echo "2. 查看容器列表"
    echo "3. 启动容器"
    echo "4. 停止容器"
    echo "5. 删除容器"
    echo "6. 查看镜像列表"
    echo "7. 拉取镜像"
    echo "8. 删除镜像"
    echo "------------------------"
    echo "0. 返回主菜单"
    echo "------------------------"
    read -e -p "请输入你的选择: " docker_choice

    case $docker_choice in
        1)
            install_docker
            ;;
        2)
            install_docker
            docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
            break_end
            ;;
        3)
            install_docker
            read -e -p "请输入容器名（多个容器名用空格分隔）: " dockername
            docker start $dockername
            echo -e "${GREEN}指定容器已启动${RESET}"
            send_stats "启动容器"
            break_end
            ;;
        4)
            install_docker
            read -e -p "请输入容器名（多个容器名用空格分隔）: " dockername
            docker stop $dockername
            echo -e "${GREEN}指定容器已停止${RESET}"
            send_stats "停止容器"
            break_end
            ;;
        5)
            install_docker
            read -e -p "请输入容器名（多个容器名用空格分隔）: " dockername
            docker rm -f $dockername
            echo -e "${GREEN}指定容器已删除${RESET}"
            send_stats "删除容器"
            break_end
            ;;
        6)
            install_docker
            docker image ls
            break_end
            ;;
        7)
            install_docker
            read -e -p "请输入镜像名（多个镜像名用空格分隔）: " imagenames
            for name in $imagenames; do
                echo -e "${YELLOW}正在拉取镜像: $name${RESET}"
                docker pull $name
            done
            echo -e "${GREEN}指定镜像已拉取${RESET}"
            send_stats "拉取镜像"
            break_end
            ;;
        8)
            install_docker
            read -e -p "请输入镜像名（多个镜像名用空格分隔）: " imagenames
            for name in $imagenames; do
                docker rmi -f $name
            done
            echo -e "${GREEN}指定镜像已删除${RESET}"
            send_stats "删除镜像"
            break_end
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择!${RESET}"
            ;;
    esac
}

# ========================
# 脚本更新
# ========================
update_script() {
    clear
    send_stats "脚本更新"
    echo -e "${CYAN}更新 SkyWRT 脚本${RESET}"
    echo "------------------------"
    local sh_v_new=$(curl -s $FALLBACK_URL | grep -o 'SH_VERSION="[0-9.]*"' | cut -d '"' -f 2)

    if [ "$SH_VERSION" = "$sh_v_new" ]; then
        echo -e "${GREEN}你已经是最新版本！${YELLOW}v$SH_VERSION${RESET}"
        send_stats "脚本已是最新版本"
    else
        echo -e "发现新版本！当前版本 v$SH_VERSION 最新版本 ${YELLOW}v$sh_v_new${RESET}"
        read -e -p "是否更新到最新版本？(y/n): " update_choice
        if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
            curl -sS -o ~/skywrt.sh $FALLBACK_URL && chmod +x ~/skywrt.sh
            cp -f ~/skywrt.sh /usr/local/bin/sw
            echo -e "${GREEN}脚本已更新到最新版本！${YELLOW}v$sh_v_new${RESET}"
            send_stats "脚本更新到 v$sh_v_new"
            break_end
            ~/skywrt.sh
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
        echo "1. 系统换源"
        echo "2. 安装常用工具"
        echo "3. Docker 管理"
        echo "4. 脚本更新"
        echo "------------------------"
        echo "0. 退出脚本"
        echo "------------------------"
        read -e -p "请输入你的选择: " choice

        case $choice in
            1)
                change_repo
                ;;
            2)
                install_tools
                ;;
            3)
                docker_manage
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
# 快捷命令处理
# ========================
if [ "$#" -eq 0 ]; then
    CheckFirstRun
    cp -f ~/skywrt.sh /usr/local/bin/sw > /dev/null 2>&1
    main_menu
else
    case $1 in
        install|add|安装)
            shift
            send_stats "安装软件"
            install "$@"
            ;;
        update|更新)
            update_script
            ;;
        docker)
            shift
            case $1 in
                install|安装)
                    send_stats "快捷安装 Docker"
                    install_docker
                    ;;
                ps|容器)
                    send_stats "快捷容器管理"
                    docker_manage
                    ;;
                *)
                    echo -e "${RED}无效的 Docker 命令!${RESET}"
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}无效的命令!${RESET}"
            echo "支持的快捷命令："
            echo "  install/add/安装 [软件包...]"
            echo "  update/更新"
            echo "  docker install/安装"
            echo "  docker ps/容器"
            ;;
    esac
fi
