#!/bin/bash
# Armbian/Debian 镜像测速 & 自动换源
# 用途：测速各镜像站，自动切换到最快的源

set -e

RED='\E[1;31m'
GREEN='\E[1;32m'
YELLOW='\E[1;33m'
BLUE='\E[1;34m'
WHITE='\E[1;37m'
cRES='\E[0m'

# 检测 Debian 版本
debian_version=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
[[ -z $debian_version ]] && debian_version="bookworm"

# 检测是否 Armbian
is_armbian=0
[[ -f /etc/armbian-release ]] && is_armbian=1
[[ -f /etc/apt/sources.list.d/armbian.list ]] && is_armbian=1

# Debian 镜像列表
debian_mirrors=(
    "mirrors.tuna.tsinghua.edu.cn|清华大学"
    "mirrors.aliyun.com|阿里云"
    "mirrors.ustc.edu.cn|中科大"
    "mirrors.163.com|网易"
    "mirrors.huaweicloud.com|华为云"
    "mirror.sjtu.edu.cn|上海交大"
    "cloudfront.debian.net|CloudFront"
    "deb.debian.org|Debian官方"
)

# Armbian 镜像列表
armbian_mirrors=(
    "mirrors.tuna.tsinghua.edu.cn/armbian|清华大学"
    "mirrors.aliyun.com/armbian|阿里云"
    "mirrors.ustc.edu.cn/armbian|中科大"
    "apt.armbian.com|Armbian官方"
)

# 测试文件（Debian 仓库都有的小文件）
test_file="dists/${debian_version}/Release"
armbian_test_file="dists/${debian_version}/main/binary-arm64/Packages.gz"

# 超时秒数
TIMEOUT=5
# 每镜像测试次数
ROUNDS=2

speedtest() {
    local mirror=$1
    local file=$2
    local total_speed=0
    local success=0

    for ((i=1; i<=ROUNDS; i++)); do
        local result
        result=$(curl -o /dev/null -s -w "%{speed_download}" \
            --connect-timeout $TIMEOUT --max-time $((TIMEOUT * 2)) \
            "http://${mirror}/${file}" 2>/dev/null)
        if [[ -n $result ]] && awk -v r="$result" 'BEGIN{exit(r>0?0:1)}'; then
            total_speed=$(awk -v t="$total_speed" -v r="$result" 'BEGIN{printf "%.0f", t+r}')
            ((success++))
        fi
    done

    if [[ $success -gt 0 ]]; then
        awk -v t="$total_speed" -v s="$success" 'BEGIN{printf "%.0f", t/s}'
    else
        echo "0"
    fi
}

# 对齐打印
print_result() {
    local name=$1
    local speed=$2
    local speed_kb
    speed_kb=$(awk -v s="$speed" 'BEGIN{printf "%.1f", s/1024}')
    printf "  %-14s %10s KB/s" "$name" "$speed_kb"
}

echo -e "${GREEN}========================================${cRES}"
echo -e "${GREEN}  Debian/Armbian 镜像测速${cRES}"
echo -e "${GREEN}  Debian 版本: ${WHITE}${debian_version}${cRES}"
if [[ $is_armbian -eq 1 ]]; then
    echo -e "${GREEN}  系统类型: ${WHITE}Armbian${cRES}"
else
    echo -e "${GREEN}  系统类型: ${WHITE}Debian${cRES}"
fi
echo -e "${GREEN}========================================${cRES}"
echo ""

# --- Debian 镜像测速 ---
echo -e "${BLUE}>>> Debian 镜像测速中...${cRES}"
echo ""

declare -A debian_speeds
for entry in "${debian_mirrors[@]}"; do
    mirror="${entry%%|*}"
    name="${entry##*|}"
    echo -ne "  ${WHITE}${name}${cRES} ... \r"
    speed=$(speedtest "$mirror" "$test_file")
    debian_speeds[$mirror]=$speed
    if [[ $speed -eq 0 ]]; then
        echo -e "  ${name}  ${RED}不可达${cRES}"
    else
        print_result "$name" "$speed"
        echo ""
    fi
done
echo ""

# --- Armbian 镜像测速 ---
if [[ $is_armbian -eq 1 ]]; then
    echo -e "${BLUE}>>> Armbian 镜像测速中...${cRES}"
    echo ""
    declare -A armbian_speeds
    for entry in "${armbian_mirrors[@]}"; do
        mirror="${entry%%|*}"
        name="${entry##*|}"
        echo -ne "  ${WHITE}${name}${cRES} ... \r"
        speed=$(speedtest "$mirror" "$armbian_test_file")
        armbian_speeds[$mirror]=$speed
        if [[ $speed -eq 0 ]]; then
            echo -e "  ${name}  ${RED}不可达${cRES}"
        else
            print_result "$name" "$speed"
            echo ""
        fi
    done
    echo ""
fi

# --- 选出最快镜像 ---
best_debian=""
best_debian_speed=0
for entry in "${debian_mirrors[@]}"; do
    mirror="${entry%%|*}"
    s=${debian_speeds[$mirror]}
    if [[ $s -gt $best_debian_speed ]]; then
        best_debian_speed=$s
        best_debian="$mirror"
    fi
done

if [[ -z $best_debian ]]; then
    echo -e "${RED}所有 Debian 镜像均不可达，退出${cRES}"
    exit 1
fi

best_armbian=""
if [[ $is_armbian -eq 1 ]]; then
    best_armbian_speed=0
    for entry in "${armbian_mirrors[@]}"; do
        mirror="${entry%%|*}"
        s=${armbian_speeds[$mirror]}
        if [[ $s -gt $best_armbian_speed ]]; then
            best_armbian_speed=$s
            best_armbian="$mirror"
        fi
    done
fi

echo -e "${GREEN}========================================${cRES}"
echo -e "${GREEN}  最快 Debian 镜像: ${WHITE}${best_debian}${cRES}"
if [[ -n $best_armbian ]]; then
    echo -e "${GREEN}  最快 Armbian 镜像: ${WHITE}${best_armbian}${cRES}"
fi
echo -e "${GREEN}========================================${cRES}"
echo ""

# --- 询问是否应用 ---
echo -ne "${YELLOW}是否切换到最快镜像？[Y/n] ${cRES}"
read -r confirm
[[ $confirm = "n" || $confirm = "N" ]] && echo -e "${YELLOW}已取消${cRES}" && exit 0

# --- 备份 ---
backup_dir="/etc/apt/sources.backup.$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
[[ -f /etc/apt/sources.list ]] && cp /etc/apt/sources.list "$backup_dir/"
[[ -f /etc/apt/sources.list.d/armbian.list ]] && cp /etc/apt/sources.list.d/armbian.list "$backup_dir/"
echo -e "${GREEN}备份已保存到: ${WHITE}${backup_dir}${cRES}"

# --- 生成新的 sources.list ---
cat << EOF > /etc/apt/sources.list
deb http://${best_debian}/debian ${debian_version} main contrib non-free non-free-firmware
deb http://${best_debian}/debian-security ${debian_version}-security main contrib non-free non-free-firmware
deb http://${best_debian}/debian ${debian_version}-updates main contrib non-free non-free-firmware
deb http://${best_debian}/debian ${debian_version}-backports main contrib non-free non-free-firmware
EOF
echo -e "${GREEN}已更新 /etc/apt/sources.list${cRES}"

# --- 生成新的 armbian.list ---
if [[ -n $best_armbian ]]; then
    cat << EOF > /etc/apt/sources.list.d/armbian.list
deb http://${best_armbian} ${debian_version} main ${debian_version}-utils ${debian_version}-desktop
EOF
    echo -e "${GREEN}已更新 /etc/apt/sources.list.d/armbian.list${cRES}"
fi

echo ""
echo -e "${GREEN}完成！执行 apt update 使更改生效。${cRES}"
