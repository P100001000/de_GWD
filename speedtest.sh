#!/bin/bash
# Armbian 镜像测速 & 自动换源
# 用途：测速各 Armbian 镜像站，自动切换到最快的源

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
[[ -f /etc/apt/sources.list.d/armbian.sources ]] && is_armbian=1

if [[ $is_armbian -eq 0 ]]; then
    echo -e "${RED}未检测到 Armbian 系统，退出${cRES}"
    exit 1
fi

# Armbian 镜像列表
armbian_mirrors=(
    "mirrors.tuna.tsinghua.edu.cn/armbian|清华大学"
    "mirrors.aliyun.com/armbian|阿里云"
    "mirrors.ustc.edu.cn/armbian|中科大"
    "mirrors.nju.edu.cn/armbian|南京大学"
    "apt.armbian.com|Armbian官方"
)

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

print_result() {
    local name=$1
    local speed=$2
    local speed_kb
    speed_kb=$(awk -v s="$speed" 'BEGIN{printf "%.1f", s/1024}')
    printf "  %-14s %10s KB/s" "$name" "$speed_kb"
}

echo -e "${GREEN}========================================${cRES}"
echo -e "${GREEN}  Armbian 镜像测速${cRES}"
echo -e "${GREEN}  版本: ${WHITE}${debian_version}${cRES}"
echo -e "${GREEN}========================================${cRES}"
echo ""

# 更新 Armbian GPG keyring（防止国内镜像签名验证失败）
wget -qO- 'https://apt.armbian.com/armbian.key' 2>/dev/null | gpg --dearmor > /usr/share/keyrings/armbian.gpg 2>/dev/null

# --- Armbian 镜像测速 ---
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

# --- 选出最快镜像 ---
best_armbian=""
best_armbian_speed=0
for entry in "${armbian_mirrors[@]}"; do
    mirror="${entry%%|*}"
    s=${armbian_speeds[$mirror]}
    if [[ $s -gt $best_armbian_speed ]]; then
        best_armbian_speed=$s
        best_armbian="$mirror"
    fi
done

if [[ -z $best_armbian ]]; then
    echo -e "${RED}所有 Armbian 镜像均不可达，退出${cRES}"
    exit 1
fi

echo -e "${GREEN}========================================${cRES}"
echo -e "${GREEN}  最快 Armbian 镜像: ${WHITE}${best_armbian}${cRES}"
echo -e "${GREEN}========================================${cRES}"
echo ""

# --- 选择镜像 ---
echo -e "${GREEN}========================================${cRES}"
# 找出最快镜像的名称
for entry in "${armbian_mirrors[@]}"; do
    [[ "${entry%%|*}" = "$best_armbian" ]] && best_name="${entry##*|}" && break
done
echo -e "${GREEN}[1]: 使用推荐（${best_name}）${cRES}"
echo -e "${GREEN}[2]: 手动选择${cRES}"
echo -e "${GREEN}[0]: 取消退出${cRES}"
echo -e "${GREEN}========================================${cRES}"
echo -ne "${YELLOW}请选择: ${cRES}"
read -r choice

selected_mirror=""
case $choice in
    0)
        echo -e "${YELLOW}已取消${cRES}" && exit 0
        ;;
    1)
        selected_mirror="$best_armbian"
        ;;
    2)
        echo ""
        echo -e "${BLUE}>>> 手动选择镜像:${cRES}"
        echo ""
        i=1
        unset mirror_keys
        mirror_keys=()
        for entry in "${armbian_mirrors[@]}"; do
            mirror="${entry%%|*}"
            name="${entry##*|}"
            s=${armbian_speeds[$mirror]}
            if [[ $s -gt 0 ]]; then
                mirror_keys+=("$mirror")
                speed_kb=$(awk -v s="$s" 'BEGIN{printf "%.1f", s/1024}')
                echo -e "  ${GREEN}[$i]${cRES} ${WHITE}${name}${cRES}  ${speed_kb} KB/s"
                ((i++))
            fi
        done
        echo -ne "${YELLOW}请选择 [1-$((i-1))]: ${cRES}"
        read -r num
        if [[ $num -ge 1 && $num -le ${#mirror_keys[@]} ]]; then
            selected_mirror="${mirror_keys[$((num-1))]}"
        else
            echo -e "${RED}无效选择${cRES}" && exit 1
        fi
        ;;
    *)
        echo -e "${YELLOW}已取消${cRES}" && exit 0
        ;;
esac

if [[ -z $selected_mirror ]]; then
    echo -e "${RED}未选择镜像，退出${cRES}"
    exit 1
fi

# --- 备份 ---
backup_dir="/etc/apt/sources.backup.$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
[[ -f /etc/apt/sources.list.d/armbian.list ]] && cp /etc/apt/sources.list.d/armbian.list "$backup_dir/"
[[ -f /etc/apt/sources.list.d/armbian.sources ]] && cp /etc/apt/sources.list.d/armbian.sources "$backup_dir/"
echo -e "${GREEN}备份已保存到: ${WHITE}${backup_dir}${cRES}"

# --- 生成新的 armbian.sources ---
rm -f /etc/apt/sources.list.d/armbian.list
cat << EOF > /etc/apt/sources.list.d/armbian.sources
Types: deb
URIs: http://${selected_mirror}
Suites: ${debian_version}
Components: main ${debian_version}-utils ${debian_version}-desktop
Signed-By: /usr/share/keyrings/armbian.gpg
EOF
echo -e "${GREEN}已更新 /etc/apt/sources.list.d/armbian.sources${cRES}"

echo ""
echo -e "${GREEN}完成！执行 apt update 使更改生效。${cRES}"
