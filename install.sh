#!/bin/bash
# Realm 完整管理脚本 - 交互式菜单版本
# 支持GitHub加速 + PROXY Protocol + 完整管理功能

# 设置删除键行为
stty erase "^?"

# 初始化变量
SELECTED_PROXY=""
CONFIG_FILE="/root/realm/config.toml"

# GitHub加速代理列表（已验证可用）
declare -A GITHUB_PROXIES=(
    ["1"]="https://hub.gitmirror.com/"
    ["2"]="https://gh-proxy.com/"
    ["3"]="直连GitHub（不使用代理）"
)

# 选择GitHub加速代理
select_github_proxy() {
    clear
    echo "—————————————————————"
    echo " GitHub 下载加速选择"
    echo "—————————————————————"
    echo ""
    echo "检测到需要从GitHub下载文件，请选择加速方式："
    echo ""
    
    for key in $(echo "${!GITHUB_PROXIES[@]}" | tr ' ' '\n' | sort -n); do
        echo " [$key] ${GITHUB_PROXIES[$key]}"
    done
    
    echo ""
    echo "推荐国内用户选择 1-2，海外用户选择 3"
    echo "—————————————————————"
    
    while true; do
        read -e -p "请选择加速方式 [1-3]: " proxy_choice
        
        if [[ "$proxy_choice" =~ ^[1-3]$ ]]; then
            if [ "$proxy_choice" == "3" ]; then
                SELECTED_PROXY=""
                echo "✅ 已选择直连GitHub"
            else
                SELECTED_PROXY="${GITHUB_PROXIES[$proxy_choice]}"
                echo "✅ 已选择加速代理: $SELECTED_PROXY"
            fi
            break
        else
            echo "❌ 无效选择，请输入 1-3 之间的数字"
        fi
    done
    
    echo ""
    read -e -p "按回车键继续..."
}

# 构建下载URL
build_download_url() {
    local github_url="$1"
    
    if [ -n "$SELECTED_PROXY" ]; then
        echo "${SELECTED_PROXY}${github_url}"
    else
        echo "$github_url"
    fi
}

# 智能下载函数
smart_download() {
    local github_url="$1"
    local output_file="$2"
    local max_retries=3
    
    echo "开始下载: $(basename "$github_url")"
    
    for ((i=1; i<=max_retries; i++)); do
        local download_url=$(build_download_url "$github_url")
        echo "尝试 $i/$max_retries: $download_url"
        
        if wget --progress=bar:force -O "$output_file" "$download_url" 2>&1; then
            echo "✅ 下载成功: $output_file"
            return 0
        else
            echo "❌ 下载失败，尝试 $i/$max_retries"
            rm -f "$output_file" 2>/dev/null
            
            if [ $i -lt $max_retries ]; then
                echo "等待3秒后重试..."
                sleep 3
            fi
        fi
    done
    
    echo "❌ 下载失败，已尝试 $max_retries 次"
    return 1
}

# 检查Realm状态
check_realm_status() {
    if [ -f "/root/realm/realm" ]; then
        echo -e "\\033[0;32m已安装\\033[0m"
    else
        echo -e "\\033[0;31m未安装\\033[0m"
    fi
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet realm 2>/dev/null; then
        echo -e "\\033[0;32m运行中\\033[0m"
    else
        echo -e "\\033[0;31m未运行\\033[0m"
    fi
}

# 检查PROXY Protocol状态
check_proxy_protocol_status() {
    if [ -f "$CONFIG_FILE" ]; then
        local send_proxy=$(grep "send_proxy = true" "$CONFIG_FILE" 2>/dev/null)
        local accept_proxy=$(grep "accept_proxy = true" "$CONFIG_FILE" 2>/dev/null)
        
        if [ -n "$send_proxy" ] && [ -n "$accept_proxy" ]; then
            echo -e "\\033[0;32m发送+接收\\033[0m"
        elif [ -n "$send_proxy" ]; then
            echo -e "\\033[0;33m仅发送\\033[0m"
        elif [ -n "$accept_proxy" ]; then
            echo -e "\\033[0;33m仅接收\\033[0m"
        else
            echo -e "\\033[0;31m未启用\\033[0m"
        fi
    else
        echo -e "\\033[0;31m未配置\\033[0m"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo " "
    echo " ████████████████████████████████████████████████████████"
    echo " █                                                      █"
    echo " █           Realm 完整管理脚本 v2.0                    █"
    echo " █         支持GitHub加速 + PROXY Protocol             █"
    echo " █                                                      █"
    echo " ████████████████████████████████████████████████████████"
    echo " "
    echo "—————————————————————————————————————————————————————————"
    echo " 📦 安装管理"
    echo "   1. 安装 Realm"
    echo "   2. 卸载 Realm"
    echo "   3. 更换 GitHub 加速代理"
    echo "—————————————————————————————————————————————————————————"
    echo " 🔧 规则管理"
    echo "   4. 添加转发规则"
    echo "   5. 查看转发规则"
    echo "   6. 删除转发规则"
    echo "   7. 修复配置文件"
    echo "—————————————————————————————————————————————————————————"
    echo " ⚙️  服务管理"
    echo "   8. 启动服务"
    echo "   9. 停止服务"
    echo "   10. 重启服务"
    echo "   11. 查看服务状态"
    echo "—————————————————————————————————————————————————————————"
    echo " 🔐 PROXY Protocol"
    echo "   12. 配置 PROXY Protocol"
    echo "   13. 查看 PROXY Protocol 状态"
    echo "—————————————————————————————————————————————————————————"
    echo " 📊 日志监控"
    echo "   14. 查看实时日志"
    echo "   15. 查看错误日志"
    echo "   16. 查看连接统计"
    echo "—————————————————————————————————————————————————————————"
    echo " 🛠️  工具功能"
    echo "   17. 测试网络连通性"
    echo "   18. 备份配置文件"
    echo "   19. 恢复配置文件"
    echo "—————————————————————————————————————————————————————————"
    echo "   0. 退出脚本"
    echo "—————————————————————————————————————————————————————————"
    echo ""
    echo -n " 📋 Realm状态: "
    check_realm_status
    echo -n " 🔄 服务状态: "
    check_service_status
    echo -n " 🔐 PROXY Protocol: "
    check_proxy_protocol_status
    
    if [ -n "$SELECTED_PROXY" ]; then
        echo -e " 🚀 GitHub加速: \\033[0;32m${SELECTED_PROXY}\\033[0m"
    else
        echo -e " 🚀 GitHub加速: \\033[0;33m直连\\033[0m"
    fi
    
    echo ""
}

# 安装Realm
install_realm() {
    clear
    echo "🚀 安装 Realm"
    echo "—————————————————————————————————————————————————————————"
    
    # 如果还没有选择代理，先选择
    if [ -z "$SELECTED_PROXY" ]; then
        select_github_proxy
    fi
    
    echo "开始安装Realm..."
    
    mkdir -p /root/realm
    cd /root/realm
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            REALM_ARCH="x86_64-unknown-linux-gnu"
            ;;
        aarch64)
            REALM_ARCH="aarch64-unknown-linux-gnu"
            ;;
        *)
            echo "不支持的架构: $ARCH，使用默认x86_64版本"
            REALM_ARCH="x86_64-unknown-linux-gnu"
            ;;
    esac
    
    # 构建GitHub下载URL
    local github_url="https://github.com/zhboner/realm/releases/latest/download/realm-${REALM_ARCH}.tar.gz"
    
    # 使用智能下载
    if smart_download "$github_url" "realm.tar.gz"; then
        echo "正在解压..."
        tar -xzf realm.tar.gz
        chmod +x realm
        
        # 验证文件
        if [ -f "realm" ] && [ -x "realm" ]; then
            echo "✅ Realm二进制文件验证成功"
        else
            echo "❌ Realm二进制文件验证失败"
            read -e -p "按回车键返回..."
            return 1
        fi
    else
        echo "❌ Realm下载失败"
        read -e -p "按回车键返回..."
        return 1
    fi
    
    # 创建服务文件
    cat > /etc/systemd/system/realm.service << 'EOF'
[Unit]
Description=realm
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
WorkingDirectory=/root/realm
ExecStart=/root/realm/realm -c /root/realm/config.toml

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    # 创建基础配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
[network]
no_tcp = false
use_udp = true
send_proxy = false
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF
    fi
    
    echo "✅ Realm安装完成"
    echo "💡 请使用菜单选项配置PROXY Protocol和添加转发规则"
    rm -f realm.tar.gz
    
    read -e -p "按回车键返回..."
}

# 卸载Realm
uninstall_realm() {
    clear
    echo "🗑️  卸载 Realm"
    echo "—————————————————————————————————————————————————————————"
    echo ""
    echo "⚠️  警告：这将删除Realm及所有配置文件！"
    echo ""
    read -e -p "确认卸载Realm? (输入 'YES' 确认): " confirm

    if [ "$confirm" = "YES" ]; then
        echo "正在卸载Realm..."

        # 停止并禁用服务
        systemctl stop realm 2>/dev/null
        systemctl disable realm 2>/dev/null

        # 删除服务文件
        rm -f /etc/systemd/system/realm.service
        systemctl daemon-reload

        # 备份配置文件
        if [ -f "$CONFIG_FILE" ]; then
            cp "$CONFIG_FILE" "/root/realm_backup_$(date +%Y%m%d_%H%M%S).toml"
            echo "✅ 配置文件已备份"
        fi

        # 删除程序目录
        rm -rf /root/realm

        echo "✅ Realm已完全卸载"
    else
        echo "❌ 已取消卸载"
    fi

    read -e -p "按回车键返回..."
}

# 更换GitHub代理
change_github_proxy() {
    clear
    echo "🚀 更换 GitHub 加速代理"
    echo "—————————————————————————————————————————————————————————"
    echo ""
    echo "当前GitHub代理设置："
    if [ -n "$SELECTED_PROXY" ]; then
        echo "  🔗 $SELECTED_PROXY"
    else
        echo "  🔗 直连GitHub"
    fi
    echo ""

    read -e -p "是否要更换GitHub代理? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        select_github_proxy
        echo "✅ GitHub代理已更新"
    else
        echo "保持当前设置"
    fi

    read -e -p "按回车键返回..."
}

# 添加转发规则
add_forward() {
    clear
    echo "➕ 添加 Realm 转发规则"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "请输入转发规则信息："
    echo ""

    read -e -p "📍 本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🌐 转发目标IP/域名: " remote_ip
    if [ -z "$remote_ip" ]; then
        echo "❌ 目标地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 转发目标端口: " remote_port
    if [ -z "$remote_port" ]; then
        echo "❌ 目标端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "📝 备注信息 (可选): " remark

    # 处理IPv6地址格式
    if [[ "$remote_ip" == *:*:* ]] && [[ "$remote_ip" != \[*\] ]]; then
        remote_format="[$remote_ip]:$remote_port"
    else
        remote_format="$remote_ip:$remote_port"
    fi

    # 添加到配置文件
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$local_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$remote_format\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ 转发规则已添加："
    echo "   📍 监听: 0.0.0.0:$local_port"
    echo "   🎯 转发: $remote_format"
    echo "   📝 备注: $remark"
    echo ""

    # 询问是否重启服务
    read -e -p "是否立即重启服务以应用配置? (Y/n): " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        systemctl restart realm
        if systemctl is-active --quiet realm; then
            echo "✅ 服务重启成功"
        else
            echo "❌ 服务重启失败，请检查配置"
        fi
    fi

    read -e -p "按回车键返回..."
}

# 查看转发规则
show_all_conf() {
    clear
    echo "📋 当前 Realm 转发规则"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    local index=1
    local current_remark=""
    local in_endpoint=false
    local found_rules=false

    echo "序号 | 监听端口        | 转发地址                     | 备注"
    echo "—————————————————————————————————————————————————————————"

    while IFS= read -r line; do
        # 检查备注行
        if [[ "$line" =~ ^#.*备注: ]]; then
            current_remark=$(echo "$line" | sed 's/^#.*备注: *//')
        # 检查endpoints开始
        elif [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
            in_endpoint=true
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            local listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            # 读取下一行获取remote
            read -r next_line
            if [[ "$next_line" =~ ^remote.*= ]]; then
                local remote_addr=$(echo "$next_line" | grep -o '"[^"]*"' | tr -d '"')

                printf " %-3s | %-15s | %-28s | %-15s\n" "$index" "$listen_port" "$remote_addr" "$current_remark"
                index=$((index + 1))
                found_rules=true

                # 重置状态
                in_endpoint=false
                current_remark=""
            fi
        fi
    done < "$CONFIG_FILE"

    if [ "$found_rules" = false ]; then
        echo "暂无转发规则"
    fi

    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "按回车键返回..."
}

# 删除转发规则
delete_forward() {
    clear
    echo "🗑️  删除 Realm 转发规则"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    # 解析并显示当前规则
    declare -a listen_ports=()
    declare -a remote_addrs=()
    declare -a remarks=()

    local index=1
    local current_remark=""
    local in_endpoint=false

    echo "当前转发规则："
    echo ""
    echo "序号 | 监听端口        | 转发地址                     | 备注"
    echo "—————————————————————————————————————————————————————————"

    while IFS= read -r line; do
        # 检查备注行
        if [[ "$line" =~ ^#.*备注: ]]; then
            current_remark=$(echo "$line" | sed 's/^#.*备注: *//')
        # 检查endpoints开始
        elif [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
            in_endpoint=true
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            local listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            # 读取下一行获取remote
            read -r next_line
            if [[ "$next_line" =~ ^remote.*= ]]; then
                local remote_addr=$(echo "$next_line" | grep -o '"[^"]*"' | tr -d '"')

                # 保存规则信息
                listen_ports+=("$listen_port")
                remote_addrs+=("$remote_addr")
                remarks+=("$current_remark")

                printf " %-3s | %-15s | %-28s | %-15s\n" "$index" "$listen_port" "$remote_addr" "$current_remark"
                index=$((index + 1))

                # 重置状态
                in_endpoint=false
                current_remark=""
            fi
        fi
    done < "$CONFIG_FILE"

    if [ ${#listen_ports[@]} -eq 0 ]; then
        echo "暂无转发规则"
        read -e -p "按回车键返回..."
        return
    fi

    echo "—————————————————————————————————————————————————————————"
    echo ""
    read -e -p "请输入要删除的规则编号 (1-${#listen_ports[@]}) 或按回车返回: " choice

    if [ -z "$choice" ]; then
        return
    fi

    # 验证输入
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#listen_ports[@]} ]; then
        echo "❌ 无效的规则编号"
        read -e -p "按回车键返回..."
        return
    fi

    # 获取选中规则的信息
    local selected_index=$((choice - 1))
    local listen_part="${listen_ports[$selected_index]}"
    local remote_part="${remote_addrs[$selected_index]}"
    local remark_part="${remarks[$selected_index]}"

    echo ""
    echo "⚠️  确认删除以下规则？"
    echo "   📍 监听端口: $listen_part"
    echo "   🎯 转发地址: $remote_part"
    echo "   📝 备注: $remark_part"
    echo ""
    read -e -p "确认删除? (输入 'YES' 确认): " confirm

    if [ "$confirm" = "YES" ]; then
        # 备份配置文件
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ 配置文件已备份"

        # 重新生成配置文件
        local temp_file="/tmp/realm_new_config.toml"

        # 先写入network部分
        grep -A 20 "^\[network\]" "$CONFIG_FILE" | grep -B 20 "^$" | head -n -1 > "$temp_file"
        echo "" >> "$temp_file"

        # 重新添加除了选中规则外的所有规则
        for ((i=0; i<${#listen_ports[@]}; i++)); do
            if [ $i -ne $selected_index ]; then
                cat >> "$temp_file" << EOF
[[endpoints]]
# 备注: ${remarks[$i]}
listen = "${listen_ports[$i]}"
remote = "${remote_addrs[$i]}"

EOF
            fi
        done

        # 替换原配置文件
        mv "$temp_file" "$CONFIG_FILE"

        echo "✅ 规则删除成功"

        # 询问是否重启服务
        read -e -p "是否立即重启服务以应用配置? (Y/n): " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            if systemctl restart realm 2>/dev/null; then
                echo "✅ 服务重启成功"
            else
                echo "❌ 服务重启失败，恢复备份配置"
                cp "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)" "$CONFIG_FILE"
                systemctl restart realm
            fi
        fi
    else
        echo "❌ 已取消删除"
    fi

    read -e -p "按回车键返回..."
}

# 修复配置文件
fix_config() {
    clear
    echo "🔧 修复配置文件"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在"
        echo ""
        echo "请选择创建配置类型："
        echo " [1] A机器配置 (发送PROXY Protocol)"
        echo " [2] B机器配置 (接收+发送PROXY Protocol)"
        echo " [3] 普通转发 (不使用PROXY Protocol)"
        echo " [0] 返回"
        echo ""
        read -e -p "请选择: " config_type

        case $config_type in
            1|2|3)
                create_basic_config "$config_type"
                ;;
            0)
                return
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
    else
        # 备份现有配置
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ 原配置已备份"

        # 测试配置文件
        echo "🔍 检查配置文件格式..."
        if systemctl restart realm 2>/dev/null; then
            echo "✅ 配置文件格式正确"
        else
            echo "❌ 配置文件格式错误，开始修复..."

            # 尝试修复配置文件
            repair_config_file
        fi
    fi

    read -e -p "按回车键返回..."
}

# 创建基础配置
create_basic_config() {
    local config_type="$1"

    case $config_type in
        1)
            # A机器配置
            cat > "$CONFIG_FILE" << 'EOF'
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF
            echo "✅ A机器配置已创建 (发送PROXY Protocol)"
            ;;
        2)
            # B机器配置
            cat > "$CONFIG_FILE" << 'EOF'
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF
            echo "✅ B机器配置已创建 (接收+发送PROXY Protocol)"
            ;;
        3)
            # 普通转发配置
            cat > "$CONFIG_FILE" << 'EOF'
[network]
no_tcp = false
use_udp = true
send_proxy = false
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF
            echo "✅ 普通转发配置已创建"
            ;;
    esac
}

# 启动服务
start_service() {
    clear
    echo "▶️  启动 Realm 服务"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "正在启动Realm服务..."
    systemctl enable realm
    systemctl start realm

    sleep 2

    if systemctl is-active --quiet realm; then
        echo "✅ Realm服务启动成功"
        echo ""
        systemctl status realm --no-pager -l
    else
        echo "❌ Realm服务启动失败"
        echo ""
        echo "错误日志："
        journalctl -u realm --no-pager -l | tail -10
    fi

    read -e -p "按回车键返回..."
}

# 停止服务
stop_service() {
    clear
    echo "⏹️  停止 Realm 服务"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "正在停止Realm服务..."
    systemctl stop realm

    sleep 2

    if ! systemctl is-active --quiet realm; then
        echo "✅ Realm服务已停止"
    else
        echo "❌ Realm服务停止失败"
    fi

    read -e -p "按回车键返回..."
}

# 重启服务
restart_service() {
    clear
    echo "🔄 重启 Realm 服务"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "正在重启Realm服务..."
    systemctl restart realm

    sleep 2

    if systemctl is-active --quiet realm; then
        echo "✅ Realm服务重启成功"
        echo ""
        systemctl status realm --no-pager -l
    else
        echo "❌ Realm服务重启失败"
        echo ""
        echo "错误日志："
        journalctl -u realm --no-pager -l | tail -10
    fi

    read -e -p "按回车键返回..."
}

# 查看服务状态
show_service_status() {
    clear
    echo "📊 Realm 服务状态"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    # 显示服务状态
    systemctl status realm --no-pager -l
    echo ""

    # 显示端口监听
    echo "📡 端口监听状态："
    echo "—————————————————————————————————————————————————————————"
    netstat -tlnp | grep realm || echo "未发现realm监听端口"
    echo ""

    # 显示进程信息
    echo "🔍 进程信息："
    echo "—————————————————————————————————————————————————————————"
    ps aux | grep realm | grep -v grep || echo "未发现realm进程"
    echo ""

    read -e -p "按回车键返回..."
}

# 配置PROXY Protocol
configure_proxy_protocol() {
    clear
    echo "🔐 配置 PROXY Protocol"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "当前PROXY Protocol配置："
    echo ""
    grep -E "(send_proxy|accept_proxy)" "$CONFIG_FILE" | head -2
    echo ""
    echo "—————————————————————————————————————————————————————————"
    echo "配置选项："
    echo " [1] A机器配置 - 发送PROXY Protocol"
    echo " [2] B机器配置 - 接收PROXY Protocol"
    echo " [3] B机器配置 - 接收+发送PROXY Protocol"
    echo " [4] 禁用PROXY Protocol"
    echo " [0] 返回主菜单"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "请选择配置选项: " proxy_choice

    case $proxy_choice in
        1)
            sed -i 's/send_proxy = .*/send_proxy = true/' "$CONFIG_FILE"
            sed -i 's/accept_proxy = .*/accept_proxy = false/' "$CONFIG_FILE"
            echo "✅ 已配置为发送PROXY Protocol (A机器)"
            ;;
        2)
            sed -i 's/send_proxy = .*/send_proxy = false/' "$CONFIG_FILE"
            sed -i 's/accept_proxy = .*/accept_proxy = true/' "$CONFIG_FILE"
            echo "✅ 已配置为接收PROXY Protocol (B机器)"
            ;;
        3)
            sed -i 's/send_proxy = .*/send_proxy = true/' "$CONFIG_FILE"
            sed -i 's/accept_proxy = .*/accept_proxy = true/' "$CONFIG_FILE"
            echo "✅ 已配置为接收+发送PROXY Protocol (B机器中转)"
            ;;
        4)
            sed -i 's/send_proxy = .*/send_proxy = false/' "$CONFIG_FILE"
            sed -i 's/accept_proxy = .*/accept_proxy = false/' "$CONFIG_FILE"
            echo "✅ 已禁用PROXY Protocol"
            ;;
        0)
            return
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            return
            ;;
    esac

    echo ""
    read -e -p "是否立即重启服务以应用配置? (Y/n): " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        systemctl restart realm
        if systemctl is-active --quiet realm; then
            echo "✅ 服务重启成功，配置已生效"
        else
            echo "❌ 服务重启失败，请检查配置"
        fi
    fi

    read -e -p "按回车键返回..."
}

# 查看PROXY Protocol状态
show_proxy_status() {
    clear
    echo "🔐 PROXY Protocol 状态"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在"
        read -e -p "按回车键返回..."
        return
    fi

    echo "📋 当前配置："
    echo ""
    local send_proxy=$(grep "send_proxy" "$CONFIG_FILE" | head -1)
    local accept_proxy=$(grep "accept_proxy" "$CONFIG_FILE" | head -1)
    local proxy_version=$(grep "send_proxy_version" "$CONFIG_FILE" | head -1)

    echo "  $send_proxy"
    echo "  $accept_proxy"
    echo "  $proxy_version"
    echo ""

    echo "🔍 状态说明："
    echo "—————————————————————————————————————————————————————————"
    echo -n "  当前模式: "
    check_proxy_protocol_status
    echo ""

    echo "📖 配置说明："
    echo "  • send_proxy = true     发送PROXY Protocol给下游"
    echo "  • accept_proxy = true   接收上游的PROXY Protocol"
    echo "  • send_proxy_version = 2 使用PROXY Protocol v2版本"
    echo ""

    echo "🏗️  典型架构："
    echo "  用户 → A机器(send=true) → B机器(send+accept=true) → XrayR"
    echo "         ↓ 发送真实IP      ↓ 接收并转发真实IP"
    echo ""

    echo "⚙️  服务状态："
    if systemctl is-active --quiet realm; then
        echo -e "  Realm服务: \\033[0;32m运行中\\033[0m"
    else
        echo -e "  Realm服务: \\033[0;31m未运行\\033[0m"
    fi
    echo ""

    read -e -p "按回车键返回..."
}

# 查看实时日志
show_realtime_logs() {
    clear
    echo "📊 Realm 实时日志监控"
    echo "—————————————————————————————————————————————————————————"
    echo ""
    echo "💡 提示：按 Ctrl+C 退出日志监控"
    echo ""
    read -e -p "按回车键开始监控..."

    clear
    echo "🔍 Realm 实时日志 (按 Ctrl+C 退出)"
    echo "========================================"

    # 显示实时日志
    journalctl -u realm -f --no-pager
}

# 查看错误日志
show_error_logs() {
    clear
    echo "❌ Realm 错误日志"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "🔍 最近的错误和警告日志："
    echo ""
    journalctl -u realm -p err --since "24 hours ago" --no-pager
    echo ""

    echo "🔍 最近的所有日志 (最后50行)："
    echo "—————————————————————————————————————————————————————————"
    journalctl -u realm -n 50 --no-pager
    echo ""

    read -e -p "按回车键返回..."
}

# 查看连接统计
show_connection_stats() {
    clear
    echo "📈 Realm 连接统计"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "📡 当前监听端口："
    echo ""
    netstat -tlnp | grep realm || echo "未发现realm监听端口"
    echo ""

    echo "🔗 当前连接数："
    echo ""
    local connections=$(netstat -an | grep -E "ESTABLISHED.*:($(netstat -tlnp | grep realm | awk '{print $4}' | cut -d: -f2 | tr '\n' '|' | sed 's/|$//'))" | wc -l)
    echo "  活跃连接数: $connections"
    echo ""

    echo "📊 连接详情："
    echo "—————————————————————————————————————————————————————————"
    netstat -an | grep -E "ESTABLISHED.*:($(netstat -tlnp | grep realm | awk '{print $4}' | cut -d: -f2 | tr '\n' '|' | sed 's/|$//'))" | head -20
    echo ""

    echo "💾 系统资源使用："
    echo "—————————————————————————————————————————————————————————"
    ps aux | grep realm | grep -v grep
    echo ""

    read -e -p "按回车键返回..."
}

# 测试网络连通性
test_network_connectivity() {
    clear
    echo "🌐 网络连通性测试"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在"
        read -e -p "按回车键返回..."
        return
    fi

    echo "🔍 解析配置文件中的转发目标..."
    echo ""

    # 提取所有remote地址
    local remotes=$(grep "remote =" "$CONFIG_FILE" | grep -o '"[^"]*"' | tr -d '"')

    if [ -z "$remotes" ]; then
        echo "❌ 未找到转发规则"
        read -e -p "按回车键返回..."
        return
    fi

    echo "📋 测试转发目标连通性："
    echo "—————————————————————————————————————————————————————————"

    while IFS= read -r remote; do
        if [ -n "$remote" ]; then
            local host=$(echo "$remote" | cut -d: -f1)
            local port=$(echo "$remote" | cut -d: -f2)

            echo -n "🎯 测试 $remote: "

            if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
                echo -e "\\033[0;32m✅ 可达\\033[0m"
            else
                echo -e "\\033[0;31m❌ 不可达\\033[0m"
            fi
        fi
    done <<< "$remotes"

    echo ""
    echo "🔍 测试本地监听端口："
    echo "—————————————————————————————————————————————————————————"

    local listens=$(grep "listen =" "$CONFIG_FILE" | grep -o '"[^"]*"' | tr -d '"')

    while IFS= read -r listen; do
        if [ -n "$listen" ]; then
            local port=$(echo "$listen" | cut -d: -f2)
            echo -n "📡 测试本地端口 $port: "

            if netstat -tln | grep ":$port " >/dev/null; then
                echo -e "\\033[0;32m✅ 监听中\\033[0m"
            else
                echo -e "\\033[0;31m❌ 未监听\\033[0m"
            fi
        fi
    done <<< "$listens"

    echo ""
    read -e -p "按回车键返回..."
}

# 备份配置文件
backup_config() {
    clear
    echo "💾 备份配置文件"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在"
        read -e -p "按回车键返回..."
        return
    fi

    local backup_dir="/root/realm_backups"
    local backup_file="$backup_dir/config_$(date +%Y%m%d_%H%M%S).toml"

    mkdir -p "$backup_dir"
    cp "$CONFIG_FILE" "$backup_file"

    echo "✅ 配置文件已备份到: $backup_file"
    echo ""
    echo "📋 备份文件信息："
    ls -la "$backup_file"
    echo ""

    echo "📁 所有备份文件："
    echo "—————————————————————————————————————————————————————————"
    ls -la "$backup_dir"/ 2>/dev/null || echo "备份目录为空"
    echo ""

    read -e -p "按回车键返回..."
}

# 恢复配置文件
restore_config() {
    clear
    echo "🔄 恢复配置文件"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    local backup_dir="/root/realm_backups"

    if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
        echo "❌ 未找到备份文件"
        read -e -p "按回车键返回..."
        return
    fi

    echo "📁 可用的备份文件："
    echo "—————————————————————————————————————————————————————————"

    local index=1
    declare -a backup_files=()

    for file in "$backup_dir"/*.toml; do
        if [ -f "$file" ]; then
            backup_files+=("$file")
            local filename=$(basename "$file")
            local filesize=$(ls -lh "$file" | awk '{print $5}')
            local filedate=$(ls -l "$file" | awk '{print $6, $7, $8}')
            printf " [%d] %-30s %s %s\n" "$index" "$filename" "$filesize" "$filedate"
            index=$((index + 1))
        fi
    done

    if [ ${#backup_files[@]} -eq 0 ]; then
        echo "❌ 未找到备份文件"
        read -e -p "按回车键返回..."
        return
    fi

    echo "—————————————————————————————————————————————————————————"
    echo ""
    read -e -p "请选择要恢复的备份文件编号 (1-${#backup_files[@]}) 或按回车返回: " choice

    if [ -z "$choice" ]; then
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backup_files[@]} ]; then
        echo "❌ 无效的文件编号"
        read -e -p "按回车键返回..."
        return
    fi

    local selected_file="${backup_files[$((choice-1))]}"

    echo ""
    echo "⚠️  确认恢复以下备份文件？"
    echo "   📁 文件: $(basename "$selected_file")"
    echo "   📅 日期: $(ls -l "$selected_file" | awk '{print $6, $7, $8}')"
    echo ""
    echo "⚠️  当前配置文件将被覆盖！"
    echo ""
    read -e -p "确认恢复? (输入 'YES' 确认): " confirm

    if [ "$confirm" = "YES" ]; then
        # 备份当前配置
        if [ -f "$CONFIG_FILE" ]; then
            cp "$CONFIG_FILE" "${CONFIG_FILE}.before_restore.$(date +%Y%m%d_%H%M%S)"
            echo "✅ 当前配置已备份"
        fi

        # 恢复配置
        cp "$selected_file" "$CONFIG_FILE"
        echo "✅ 配置文件已恢复"

        # 询问是否重启服务
        read -e -p "是否立即重启服务以应用配置? (Y/n): " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            if systemctl restart realm 2>/dev/null; then
                echo "✅ 服务重启成功"
            else
                echo "❌ 服务重启失败，请检查配置"
            fi
        fi
    else
        echo "❌ 已取消恢复"
    fi

    read -e -p "按回车键返回..."
}

# 主循环
while true; do
    show_menu
    read -e -p "请选择功能 [0-19]: " choice

    # 去掉输入中的空格
    choice=$(echo $choice | tr -d '[:space:]')

    case $choice in
        1) install_realm ;;
        2) uninstall_realm ;;
        3) change_github_proxy ;;
        4) add_forward ;;
        5) show_all_conf ;;
        6) delete_forward ;;
        7) fix_config ;;
        8) start_service ;;
        9) stop_service ;;
        10) restart_service ;;
        11) show_service_status ;;
        12) configure_proxy_protocol ;;
        13) show_proxy_status ;;
        14) show_realtime_logs ;;
        15) show_error_logs ;;
        16) show_connection_stats ;;
        17) test_network_connectivity ;;
        18) backup_config ;;
        19) restore_config ;;
        0)
            clear
            echo ""
            echo "感谢使用 Realm 管理脚本！"
            echo ""
            echo "🎉 如果PROXY Protocol配置成功，您应该能看到："
            echo "   • XrayR日志中显示真实用户IP"
            echo "   • 连接数限制按真实IP生效"
            echo "   • 用户IP记录准确无误"
            echo ""
            echo "📞 如有问题，请检查："
            echo "   • A机器: send_proxy=true, accept_proxy=false"
            echo "   • B机器: send_proxy=true, accept_proxy=true"
            echo "   • XrayR: 启用PROXY Protocol接收"
            echo ""
            echo "再见！👋"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo "❌ 无效选项: $choice"
            echo "请输入 0-19 之间的数字"
            sleep 2
            ;;
    esac
done
