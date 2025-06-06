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
    echo "🌟 Realm 网络转发管理工具 v2.0"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    # 显示状态信息
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
    echo "—————————————————————————————————————————————————————————"
    echo ""

    # 紧凑型菜单布局
    echo " 📦 基础管理        🔧 规则管理        ⚙️  服务管理"
    echo "  1. 安装 Realm      4. 添加规则        8. 启动服务"
    echo "  2. 卸载 Realm      5. 查看规则        9. 停止服务"
    echo "  3. GitHub代理      6. 删除规则        10. 重启服务"
    echo "                     7. 修复配置        11. 服务状态"
    echo ""
    echo " 🔐 PROXY协议       🌐 传输层配置      📊 监控工具"
    echo "  12. 配置PROXY      17. WS隧道配置     19. 实时日志"
    echo "  13. PROXY状态      18. 传输层状态     20. 错误日志"
    echo "                     14. WebSocket      21. 连接统计"
    echo "                     15. TLS加密        22. 网络测试"
    echo "                     16. WSS配置"
    echo ""
    echo " 🛠️  系统工具"
    echo "  23. 备份配置       24. 恢复配置       25. 更新脚本"
    echo ""
    echo "—————————————————————————————————————————————————————————"
    echo " 0. 退出脚本"
    echo "—————————————————————————————————————————————————————————"
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
    echo "请选择操作："
    echo " [1] 确认卸载"
    echo " [0] 取消卸载"
    echo ""
    read -e -p "请选择 (1/0): " confirm

    if [ "$confirm" = "1" ]; then
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

    # 验证端口号格式
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [ "$local_port" -lt 1 ] || [ "$local_port" -gt 65535 ]; then
        echo "❌ 端口号无效，请输入1-65535之间的数字"
        read -e -p "按回车键返回..."
        return
    fi

    # 检查端口是否已被占用
    echo "🔍 检查端口 $local_port 可用性..."
    if netstat -tln | grep ":$local_port " >/dev/null 2>&1; then
        echo "⚠️  警告：端口 $local_port 已被占用"
        echo ""
        echo "当前占用端口 $local_port 的进程："
        netstat -tlnp | grep ":$local_port " 2>/dev/null || echo "无法获取进程信息"
        echo ""
        read -e -p "是否继续使用此端口? (y/N): " continue_confirm
        if [[ ! "$continue_confirm" =~ ^[Yy]$ ]]; then
            echo "❌ 已取消添加规则"
            read -e -p "按回车键返回..."
            return
        fi
    else
        echo "✅ 端口 $local_port 可用"
    fi

    # 检查是否与现有规则冲突
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "listen = \"0.0.0.0:$local_port\"" "$CONFIG_FILE"; then
            echo "❌ 端口 $local_port 已在Realm配置中使用"
            echo ""
            echo "现有规则："
            grep -A 2 -B 1 "listen = \"0.0.0.0:$local_port\"" "$CONFIG_FILE"
            echo ""
            read -e -p "按回车键返回..."
            return
        fi
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
    read -e -p "是否立即重启服务以应用配置? (Y/n，默认Y): " restart_confirm
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
    declare -a transports=()

    local index=1
    local current_remark=""
    local current_listen=""
    local current_remote=""
    local current_transport=""
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
            current_listen=""
            current_remote=""
            current_transport=""
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            current_listen=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查remote行
        elif [[ "$line" =~ ^remote.*= ]] && [ "$in_endpoint" = true ]; then
            current_remote=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查transport行
        elif [[ "$line" =~ ^transport.*= ]] && [ "$in_endpoint" = true ]; then
            current_transport=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查空行或下一个section，表示当前endpoint结束
        elif [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^\[ ]] && [ "$in_endpoint" = true ]; then
            if [ -n "$current_listen" ] && [ -n "$current_remote" ]; then
                # 保存规则信息
                listen_ports+=("$current_listen")
                remote_addrs+=("$current_remote")
                remarks+=("$current_remark")
                transports+=("$current_transport")

                printf " %-3s | %-15s | %-28s | %-15s\n" "$index" "$current_listen" "$current_remote" "$current_remark"
                index=$((index + 1))
            fi

            # 重置状态
            in_endpoint=false
            current_remark=""
            current_listen=""
            current_remote=""
            current_transport=""
        fi
    done < "$CONFIG_FILE"

    # 处理文件末尾的最后一个endpoint
    if [ "$in_endpoint" = true ] && [ -n "$current_listen" ] && [ -n "$current_remote" ]; then
        listen_ports+=("$current_listen")
        remote_addrs+=("$current_remote")
        remarks+=("$current_remark")
        transports+=("$current_transport")
        printf " %-3s | %-15s | %-28s | %-15s\n" "$index" "$current_listen" "$current_remote" "$current_remark"
    fi

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
    echo "—————————————————————————————————————————————————————————"
    echo "   📍 监听端口: $listen_part"
    echo "   🎯 转发地址: $remote_part"
    echo "   📝 备注信息: ${remark_part:-无备注}"
    if [ -n "${transports[$selected_index]}" ]; then
        echo "   🌐 传输协议: ${transports[$selected_index]}"
    else
        echo "   🌐 传输协议: TCP (默认)"
    fi
    echo "—————————————————————————————————————————————————————————"
    echo ""
    echo "⚠️  警告：删除后需要重启服务才能生效！"
    echo ""
    echo "请选择操作："
    echo " [1] 确认删除"
    echo " [0] 取消删除 (默认)"
    echo ""
    read -e -p "请输入数字选择 (1/0，默认0): " confirm

    # 默认为取消删除
    if [ -z "$confirm" ]; then
        confirm="0"
    fi

    if [ "$confirm" = "1" ]; then
        # 备份配置文件
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ 配置文件已备份"

        # 重新生成配置文件
        local temp_file="/tmp/realm_new_config.toml"

        # 读取当前的PROXY Protocol配置
        local current_send_proxy=$(grep "send_proxy = " "$CONFIG_FILE" | head -1 | grep -o 'true\|false')
        local current_accept_proxy=$(grep "accept_proxy = " "$CONFIG_FILE" | head -1 | grep -o 'true\|false')
        local current_proxy_version=$(grep "send_proxy_version = " "$CONFIG_FILE" | head -1 | grep -o '[0-9]')

        # 如果没有找到配置，使用默认值
        if [ -z "$current_send_proxy" ]; then
            current_send_proxy="false"
        fi
        if [ -z "$current_accept_proxy" ]; then
            current_accept_proxy="false"
        fi
        if [ -z "$current_proxy_version" ]; then
            current_proxy_version="2"
        fi

        # 先写入network部分，保持原有的PROXY Protocol配置
        cat > "$temp_file" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = $current_send_proxy
accept_proxy = $current_accept_proxy
send_proxy_version = $current_proxy_version
tcp_timeout = 10
tcp_nodelay = true

EOF

        # 重新添加除了选中规则外的所有规则
        for ((i=0; i<${#listen_ports[@]}; i++)); do
            if [ $i -ne $selected_index ]; then
                cat >> "$temp_file" << EOF
[[endpoints]]
# 备注: ${remarks[$i]}
listen = "${listen_ports[$i]}"
remote = "${remote_addrs[$i]}"
EOF
                # 如果有transport配置，添加它
                if [ -n "${transports[$i]}" ]; then
                    echo "transport = \"${transports[$i]}\"" >> "$temp_file"
                fi
                echo "" >> "$temp_file"
            fi
        done

        # 替换原配置文件
        mv "$temp_file" "$CONFIG_FILE"

        echo "✅ 规则删除成功"

        # 询问是否重启服务
        read -e -p "是否立即重启服务以应用配置? (Y/n，默认Y): " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            if systemctl restart realm 2>/dev/null; then
                echo "✅ 服务重启成功"
            else
                echo "❌ 服务重启失败，恢复备份配置"
                # 找到最新的备份文件
                local latest_backup=$(ls -t "${CONFIG_FILE}.backup."* 2>/dev/null | head -1)
                if [ -n "$latest_backup" ]; then
                    cp "$latest_backup" "$CONFIG_FILE"
                    echo "✅ 已恢复备份配置: $(basename "$latest_backup")"
                    systemctl restart realm
                else
                    echo "❌ 未找到备份文件"
                fi
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

# 修复配置文件
repair_config_file() {
    echo "🔧 正在修复配置文件..."

    # 备份损坏的配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.broken.$(date +%Y%m%d_%H%M%S)"
    echo "✅ 损坏的配置已备份"

    # 解析现有的规则
    declare -a listen_ports=()
    declare -a remote_addrs=()
    declare -a remarks=()
    declare -a transports=()

    local current_remark=""
    local current_transport=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*备注: ]]; then
            current_remark=$(echo "$line" | sed 's/^#.*备注: *//')
        elif [[ "$line" =~ ^listen.*= ]]; then
            local listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            if [ -n "$listen_port" ]; then
                listen_ports+=("$listen_port")
                remarks+=("${current_remark:-}")
                current_remark=""
            fi
        elif [[ "$line" =~ ^remote.*= ]]; then
            local remote_addr=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            if [ -n "$remote_addr" ]; then
                remote_addrs+=("$remote_addr")
            fi
        elif [[ "$line" =~ ^transport.*= ]]; then
            local transport=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            transports+=("${transport:-}")
        fi
    done < "$CONFIG_FILE"

    echo "找到 ${#listen_ports[@]} 个规则，正在重新生成配置..."

    # 读取当前的PROXY Protocol配置（如果存在）
    local current_send_proxy="true"
    local current_accept_proxy="true"
    local current_proxy_version="2"

    if [ -f "${CONFIG_FILE}.backup."* ]; then
        local latest_backup=$(ls -t "${CONFIG_FILE}.backup."* 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            current_send_proxy=$(grep "send_proxy = " "$latest_backup" | head -1 | grep -o 'true\|false' || echo "true")
            current_accept_proxy=$(grep "accept_proxy = " "$latest_backup" | head -1 | grep -o 'true\|false' || echo "true")
            current_proxy_version=$(grep "send_proxy_version = " "$latest_backup" | head -1 | grep -o '[0-9]' || echo "2")
        fi
    fi

    # 重新生成配置文件，保持原有的PROXY Protocol配置
    cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = $current_send_proxy
accept_proxy = $current_accept_proxy
send_proxy_version = $current_proxy_version
tcp_timeout = 10
tcp_nodelay = true

EOF

    # 重新添加所有规则
    for ((i=0; i<${#listen_ports[@]}; i++)); do
        cat >> "$CONFIG_FILE" << EOF
[[endpoints]]
# 备注: ${remarks[$i]}
listen = "${listen_ports[$i]}"
remote = "${remote_addrs[$i]}"
EOF

        # 如果有transport配置，添加它
        if [ -n "${transports[$i]}" ]; then
            echo "transport = \"${transports[$i]}\"" >> "$CONFIG_FILE"
        fi

        echo "" >> "$CONFIG_FILE"
    done

    echo "✅ 配置文件已修复"
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
    read -e -p "是否立即重启服务以应用配置? (Y/n，默认Y): " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        echo "🔄 正在重启Realm服务..."
        if systemctl restart realm 2>/dev/null; then
            sleep 2
            if systemctl is-active --quiet realm; then
                echo "✅ 服务重启成功，配置已生效"
            else
                echo "⚠️  服务重启完成，但状态检查异常"
                echo "💡 配置已保存，请手动检查服务状态"
            fi
        else
            echo "❌ 服务重启失败，请检查配置文件"
            echo "🔍 可以使用选项11查看服务状态"
        fi
    else
        echo "⚠️  配置已保存，但未重启服务"
        echo "💡 请手动重启服务以应用配置"
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

# 配置WebSocket传输
configure_websocket() {
    clear
    echo "🌐 配置 WebSocket 传输"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "WebSocket配置说明："
    echo "• 客户端接收TCP连接，通过WebSocket发送到服务端"
    echo "• 服务端接收WebSocket连接，转发为TCP连接"
    echo "• 可以穿透HTTP代理和防火墙"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    # 选择配置类型
    echo "请选择配置类型："
    echo " [1] 客户端配置 (TCP → WebSocket)"
    echo " [2] 服务端配置 (WebSocket → TCP)"
    echo " [0] 返回"
    echo ""
    read -e -p "请选择: " ws_type

    case $ws_type in
        1)
            configure_websocket_client
            ;;
        2)
            configure_websocket_server
            ;;
        0)
            return
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            ;;
    esac
}

# 配置WebSocket客户端
configure_websocket_client() {
    echo ""
    echo "🔧 配置WebSocket客户端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🌐 WebSocket服务器地址: " ws_server
    if [ -z "$ws_server" ]; then
        echo "❌ 服务器地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 WebSocket服务器端口: " ws_port
    if [ -z "$ws_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🏠 HTTP Host (如: example.com，直接IP连接可留空): " http_host
    if [ -z "$http_host" ]; then
        echo "⚠️  HTTP Host为空，将使用目标服务器地址"
        http_host="$ws_server"
    fi

    read -e -p "📂 WebSocket路径 (如: /ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    read -e -p "📝 备注信息 (可选): " remark

    # 添加WebSocket客户端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (WebSocket客户端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$local_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$ws_server:$ws_port\"" >> "$CONFIG_FILE"
    echo "transport = \"ws;host=$http_host;path=$ws_path\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ WebSocket客户端配置已添加："
    echo "   📍 监听: 0.0.0.0:$local_port"
    echo "   🎯 连接: $ws_server:$ws_port"
    echo "   🌐 Host: $http_host"
    echo "   📂 路径: $ws_path"
    echo ""

    restart_service_prompt
}

# 配置WebSocket服务端
configure_websocket_server() {
    echo ""
    echo "🔧 配置WebSocket服务端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 WebSocket监听端口: " ws_port
    if [ -z "$ws_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🎯 转发目标地址: " target_host
    if [ -z "$target_host" ]; then
        echo "❌ 目标地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 转发目标端口: " target_port
    if [ -z "$target_port" ]; then
        echo "❌ 目标端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🏠 HTTP Host (如: example.com，可留空使用默认值): " http_host
    if [ -z "$http_host" ]; then
        echo "⚠️  HTTP Host为空，将使用默认值 'localhost'"
        http_host="localhost"
    fi

    read -e -p "📂 WebSocket路径 (如: /ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    read -e -p "📝 备注信息 (可选): " remark

    # 处理IPv6地址格式
    if [[ "$target_host" == *:*:* ]] && [[ "$target_host" != \[*\] ]]; then
        target_format="[$target_host]:$target_port"
    else
        target_format="$target_host:$target_port"
    fi

    # 添加WebSocket服务端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (WebSocket服务端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$ws_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$target_format\"" >> "$CONFIG_FILE"
    echo "transport = \"ws;host=$http_host;path=$ws_path\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ WebSocket服务端配置已添加："
    echo "   📍 监听: 0.0.0.0:$ws_port"
    echo "   🎯 转发: $target_format"
    echo "   🌐 Host: $http_host"
    echo "   📂 路径: $ws_path"
    echo ""

    restart_service_prompt
}

# 配置TLS传输
configure_tls() {
    clear
    echo "🔐 配置 TLS 传输"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "TLS配置说明："
    echo "• 客户端接收TCP连接，通过TLS加密发送到服务端"
    echo "• 服务端接收TLS连接，解密后转发为TCP连接"
    echo "• 提供传输层加密保护"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    # 选择配置类型
    echo "请选择配置类型："
    echo " [1] 客户端配置 (TCP → TLS)"
    echo " [2] 服务端配置 (TLS → TCP)"
    echo " [0] 返回"
    echo ""
    read -e -p "请选择: " tls_type

    case $tls_type in
        1)
            configure_tls_client
            ;;
        2)
            configure_tls_server
            ;;
        0)
            return
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            ;;
    esac
}

# 配置TLS客户端
configure_tls_client() {
    echo ""
    echo "🔧 配置TLS客户端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🌐 TLS服务器地址: " tls_server
    if [ -z "$tls_server" ]; then
        echo "❌ 服务器地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 TLS服务器端口: " tls_port
    if [ -z "$tls_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🏷️  SNI (服务器名称，如: example.com): " sni
    if [ -z "$sni" ]; then
        echo "❌ SNI不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔒 跳过证书验证? (y/N): " insecure
    read -e -p "📝 备注信息 (可选): " remark

    # 构建transport配置
    local transport_config="tls;sni=$sni"
    if [[ "$insecure" =~ ^[Yy]$ ]]; then
        transport_config="$transport_config;insecure"
    fi

    # 添加TLS客户端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (TLS客户端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$local_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$tls_server:$tls_port\"" >> "$CONFIG_FILE"
    echo "transport = \"$transport_config\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ TLS客户端配置已添加："
    echo "   📍 监听: 0.0.0.0:$local_port"
    echo "   🎯 连接: $tls_server:$tls_port"
    echo "   🏷️  SNI: $sni"
    if [[ "$insecure" =~ ^[Yy]$ ]]; then
        echo "   🔒 证书验证: 已跳过"
    fi
    echo ""

    restart_service_prompt
}

# 配置TLS服务端
configure_tls_server() {
    echo ""
    echo "🔧 配置TLS服务端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 TLS监听端口: " tls_port
    if [ -z "$tls_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🎯 转发目标地址: " target_host
    if [ -z "$target_host" ]; then
        echo "❌ 目标地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 转发目标端口: " target_port
    if [ -z "$target_port" ]; then
        echo "❌ 目标端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    echo ""
    echo "证书配置选项："
    echo " [1] 使用现有证书文件"
    echo " [2] 生成自签名证书"
    echo ""
    read -e -p "请选择: " cert_option

    local transport_config="tls"

    case $cert_option in
        1)
            read -e -p "🔑 私钥文件路径: " key_path
            if [ -z "$key_path" ]; then
                echo "❌ 私钥路径不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            read -e -p "📜 证书文件路径: " cert_path
            if [ -z "$cert_path" ]; then
                echo "❌ 证书路径不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            # 验证文件是否存在
            if [ ! -f "$key_path" ]; then
                echo "❌ 私钥文件不存在: $key_path"
                read -e -p "按回车键返回..."
                return
            fi

            if [ ! -f "$cert_path" ]; then
                echo "❌ 证书文件不存在: $cert_path"
                read -e -p "按回车键返回..."
                return
            fi

            transport_config="$transport_config;cert=$cert_path;key=$key_path"
            ;;
        2)
            read -e -p "🏷️  服务器名称 (CN): " server_name
            if [ -z "$server_name" ]; then
                echo "❌ 服务器名称不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            transport_config="$transport_config;servername=$server_name"
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            return
            ;;
    esac

    read -e -p "📝 备注信息 (可选): " remark

    # 处理IPv6地址格式
    if [[ "$target_host" == *:*:* ]] && [[ "$target_host" != \[*\] ]]; then
        target_format="[$target_host]:$target_port"
    else
        target_format="$target_host:$target_port"
    fi

    # 添加TLS服务端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (TLS服务端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$tls_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$target_format\"" >> "$CONFIG_FILE"
    echo "transport = \"$transport_config\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ TLS服务端配置已添加："
    echo "   📍 监听: 0.0.0.0:$tls_port"
    echo "   🎯 转发: $target_format"
    if [ "$cert_option" == "1" ]; then
        echo "   🔑 私钥: $key_path"
        echo "   📜 证书: $cert_path"
    else
        echo "   🏷️  服务器名: $server_name (自签名)"
    fi
    echo ""

    restart_service_prompt
}

# 配置WSS (WebSocket over TLS)
configure_wss() {
    clear
    echo "🔐🌐 配置 WebSocket over TLS (WSS)"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "WSS配置说明："
    echo "• 结合WebSocket和TLS的优势"
    echo "• 提供加密的WebSocket连接"
    echo "• 可以穿透HTTPS代理"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    # 选择配置类型
    echo "请选择配置类型："
    echo " [1] 客户端配置 (TCP → WSS)"
    echo " [2] 服务端配置 (WSS → TCP)"
    echo " [0] 返回"
    echo ""
    read -e -p "请选择: " wss_type

    case $wss_type in
        1)
            configure_wss_client
            ;;
        2)
            configure_wss_server
            ;;
        0)
            return
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            ;;
    esac
}

# 配置WSS客户端
configure_wss_client() {
    echo ""
    echo "🔧 配置WSS客户端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🌐 WSS服务器地址: " wss_server
    if [ -z "$wss_server" ]; then
        echo "❌ 服务器地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 WSS服务器端口: " wss_port
    if [ -z "$wss_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🏠 HTTP Host (如: example.com，直接IP连接可留空): " http_host
    if [ -z "$http_host" ]; then
        echo "⚠️  HTTP Host为空，将使用目标服务器地址"
        http_host="$wss_server"
    fi

    read -e -p "📂 WebSocket路径 (如: /ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    read -e -p "🏷️  SNI (如: example.com): " sni
    if [ -z "$sni" ]; then
        sni="$http_host"
    fi

    read -e -p "🔒 跳过证书验证? (y/N): " insecure
    read -e -p "📝 备注信息 (可选): " remark

    # 构建transport配置
    local transport_config="ws;host=$http_host;path=$ws_path;tls;sni=$sni"
    if [[ "$insecure" =~ ^[Yy]$ ]]; then
        transport_config="$transport_config;insecure"
    fi

    # 添加WSS客户端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (WSS客户端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$local_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$wss_server:$wss_port\"" >> "$CONFIG_FILE"
    echo "transport = \"$transport_config\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ WSS客户端配置已添加："
    echo "   📍 监听: 0.0.0.0:$local_port"
    echo "   🎯 连接: $wss_server:$wss_port"
    echo "   🌐 Host: $http_host"
    echo "   📂 路径: $ws_path"
    echo "   🏷️  SNI: $sni"
    if [[ "$insecure" =~ ^[Yy]$ ]]; then
        echo "   🔒 证书验证: 已跳过"
    fi
    echo ""

    restart_service_prompt
}

# 配置WSS服务端
configure_wss_server() {
    echo ""
    echo "🔧 配置WSS服务端"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "📍 WSS监听端口: " wss_port
    if [ -z "$wss_port" ]; then
        echo "❌ 端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🎯 转发目标地址: " target_host
    if [ -z "$target_host" ]; then
        echo "❌ 目标地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 转发目标端口: " target_port
    if [ -z "$target_port" ]; then
        echo "❌ 目标端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🏠 HTTP Host (如: example.com，可留空使用默认值): " http_host
    if [ -z "$http_host" ]; then
        echo "⚠️  HTTP Host为空，将使用默认值 'localhost'"
        http_host="localhost"
    fi

    read -e -p "📂 WebSocket路径 (如: /ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    echo ""
    echo "证书配置选项："
    echo " [1] 使用现有证书文件"
    echo " [2] 生成自签名证书"
    echo ""
    read -e -p "请选择: " cert_option

    local transport_config="ws;host=$http_host;path=$ws_path;tls"

    case $cert_option in
        1)
            read -e -p "🔑 私钥文件路径: " key_path
            if [ -z "$key_path" ]; then
                echo "❌ 私钥路径不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            read -e -p "📜 证书文件路径: " cert_path
            if [ -z "$cert_path" ]; then
                echo "❌ 证书路径不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            # 验证文件是否存在
            if [ ! -f "$key_path" ]; then
                echo "❌ 私钥文件不存在: $key_path"
                read -e -p "按回车键返回..."
                return
            fi

            if [ ! -f "$cert_path" ]; then
                echo "❌ 证书文件不存在: $cert_path"
                read -e -p "按回车键返回..."
                return
            fi

            transport_config="$transport_config;cert=$cert_path;key=$key_path"
            ;;
        2)
            read -e -p "🏷️  服务器名称 (CN): " server_name
            if [ -z "$server_name" ]; then
                echo "❌ 服务器名称不能为空"
                read -e -p "按回车键返回..."
                return
            fi

            transport_config="$transport_config;servername=$server_name"
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            return
            ;;
    esac

    read -e -p "📝 备注信息 (可选): " remark

    # 处理IPv6地址格式
    if [[ "$target_host" == *:*:* ]] && [[ "$target_host" != \[*\] ]]; then
        target_format="[$target_host]:$target_port"
    else
        target_format="$target_host:$target_port"
    fi

    # 添加WSS服务端配置
    echo "" >> "$CONFIG_FILE"
    echo "[[endpoints]]" >> "$CONFIG_FILE"
    echo "# 备注: $remark (WSS服务端)" >> "$CONFIG_FILE"
    echo "listen = \"0.0.0.0:$wss_port\"" >> "$CONFIG_FILE"
    echo "remote = \"$target_format\"" >> "$CONFIG_FILE"
    echo "transport = \"$transport_config\"" >> "$CONFIG_FILE"

    echo ""
    echo "✅ WSS服务端配置已添加："
    echo "   📍 监听: 0.0.0.0:$wss_port"
    echo "   🎯 转发: $target_format"
    echo "   🌐 Host: $http_host"
    echo "   📂 路径: $ws_path"
    if [ "$cert_option" == "1" ]; then
        echo "   🔑 私钥: $key_path"
        echo "   📜 证书: $cert_path"
    else
        echo "   🏷️  服务器名: $server_name (自签名)"
    fi
    echo ""

    restart_service_prompt
}

# 一键配置WS隧道转发
configure_ws_tunnel() {
    clear
    echo "🚀 一键配置 WebSocket 隧道转发"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在，请先安装Realm"
        read -e -p "按回车键返回..."
        return
    fi

    echo "WebSocket隧道特点："
    echo "✅ 无需SSL证书，配置简单"
    echo "✅ 可穿透HTTP代理和防火墙"
    echo "✅ 伪装成正常网页访问"
    echo "✅ 适合快速部署和测试"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    # 选择配置类型
    echo "请选择配置类型："
    echo " [1] 完整隧道配置（A机器+B机器）"
    echo " [2] 仅配置A机器（WS客户端）"
    echo " [3] 仅配置B机器（WS服务端）"
    echo " [4] 双栈隧道配置（IPv4监听+IPv6转发）"
    echo " [5] 纯IPv6隧道配置（IPv6监听+IPv6转发）"
    echo " [6] 反向双栈配置（IPv6监听+IPv4转发）"
    echo " [0] 返回"
    echo ""
    read -e -p "请选择: " config_type

    case $config_type in
        1)
            configure_complete_ws_tunnel
            ;;
        2)
            configure_ws_client_only
            ;;
        3)
            configure_ws_server_only
            ;;
        4)
            configure_dual_stack_tunnel
            ;;
        5)
            configure_pure_ipv6_tunnel
            ;;
        6)
            configure_reverse_dual_stack_tunnel
            ;;
        0)
            return
            ;;
        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            ;;
    esac
}

# 完整WS隧道配置
configure_complete_ws_tunnel() {
    echo ""
    echo "🔧 完整WebSocket隧道配置"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "请提供以下信息："
    echo ""

    # 获取B机器信息
    read -e -p "🌐 B机器IP地址: " b_machine_ip
    if [ -z "$b_machine_ip" ]; then
        echo "❌ B机器IP不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    # 获取XrayR信息
    read -e -p "🎯 XrayR节点地址: " xrayr_host
    if [ -z "$xrayr_host" ]; then
        echo "❌ XrayR地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 XrayR节点端口: " xrayr_port
    if [ -z "$xrayr_port" ]; then
        echo "❌ XrayR端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    # 获取端口配置
    read -e -p "📍 A机器监听端口 (如: 29731 29732): " listen_ports
    if [ -z "$listen_ports" ]; then
        listen_ports="29731"
    fi

    read -e -p "🔌 B机器WS端口 (默认8080): " ws_port
    if [ -z "$ws_port" ]; then
        ws_port="8080"
    fi

    # 生成伪装域名
    local fake_domain="www.microsoft.com"
    read -e -p "🎭 伪装域名 (默认: $fake_domain): " custom_domain
    if [ -n "$custom_domain" ]; then
        fake_domain="$custom_domain"
    fi

    # 添加备注功能
    read -e -p "📝 备注信息 (可选，如: 香港节点转发): " tunnel_remark
    if [ -z "$tunnel_remark" ]; then
        tunnel_remark="WS隧道转发"
    fi

    echo ""
    echo "📋 配置摘要："
    echo "  🌐 B机器IP: $b_machine_ip"
    echo "  🎯 XrayR: $xrayr_host:$xrayr_port"
    echo "  📍 A机器端口: $listen_ports"
    echo "  🔌 B机器端口: $ws_port"
    echo "  🎭 伪装域名: $fake_domain"
    echo "  📝 备注信息: $tunnel_remark"
    echo ""

    read -e -p "确认配置? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ 已取消配置"
        read -e -p "按回车键返回..."
        return
    fi

    # 生成配置文件
    echo ""
    echo "📝 生成配置文件..."

    # 处理IPv6地址格式
    local target_format
    if [[ "$xrayr_host" == *:*:* ]] && [[ "$xrayr_host" != \[*\] ]]; then
        target_format="[$xrayr_host]:$xrayr_port"
    else
        target_format="$xrayr_host:$xrayr_port"
    fi

    # 备份现有配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # 检测当前机器类型
    echo ""
    echo "请确认当前机器类型："
    echo " [1] A机器（国内服务器）"
    echo " [2] B机器（海外服务器）"
    echo ""
    read -e -p "当前机器是: " current_machine

    case $current_machine in
        1)
            # A机器配置
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF

            # 为每个端口添加WS客户端配置
            local port_count=1
            for port in $listen_ports; do
                local ws_path="/ws"
                if [ $port_count -gt 1 ]; then
                    ws_path="/ws$port_count"
                fi

                cat >> "$CONFIG_FILE" << EOF
[[endpoints]]
# 备注: $tunnel_remark - A机器端口$port
listen = "0.0.0.0:$port"
remote = "$b_machine_ip:$ws_port"
transport = "ws;host=$fake_domain;path=$ws_path"

EOF
                port_count=$((port_count + 1))
            done

            echo "✅ A机器WS客户端配置完成！"
            echo ""
            echo "📋 A机器配置摘要："
            echo "  📍 监听端口: $listen_ports"
            echo "  🎯 连接目标: $b_machine_ip:$ws_port"
            echo "  🎭 伪装域名: $fake_domain"
            echo ""
            echo "📝 B机器配置命令："
            echo "在B机器上运行相同脚本，选择选项17 → 1，使用以下信息："
            echo "  XrayR地址: $xrayr_host"
            echo "  XrayR端口: $xrayr_port"
            echo "  WS端口: $ws_port"
            echo "  伪装域名: $fake_domain"
            ;;

        2)
            # B机器配置
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

[[endpoints]]
# 备注: $tunnel_remark - B机器服务端
listen = "0.0.0.0:$ws_port"
remote = "$target_format"
transport = "ws;host=$fake_domain;path=/ws"

EOF

            echo "✅ B机器WS服务端配置完成！"
            echo ""
            echo "📋 B机器配置摘要："
            echo "  📍 监听端口: $ws_port"
            echo "  🎯 转发目标: $target_format"
            echo "  🎭 伪装域名: $fake_domain"
            echo ""
            echo "🔥 防火墙设置："
            echo "  ufw allow $ws_port"
            echo ""
            echo "📝 A机器配置命令："
            echo "在A机器上运行相同脚本，选择选项17 → 1，使用以下信息："
            echo "  B机器IP: $b_machine_ip"
            echo "  监听端口: $listen_ports"
            echo "  WS端口: $ws_port"
            echo "  伪装域名: $fake_domain"
            ;;

        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            return
            ;;
    esac

    restart_service_prompt
}

# 双栈隧道配置（IPv4监听+IPv6转发）
configure_dual_stack_tunnel() {
    echo ""
    echo "🌐 双栈隧道配置（IPv4监听+IPv6转发）"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "双栈隧道特点："
    echo "✅ A机器：用户IPv4连接，向B机器IPv6转发"
    echo "✅ B机器：IPv6监听，向XrayR IPv4转发"
    echo "✅ 适合双栈服务器环境"
    echo "✅ 充分利用IPv6网络优势"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    # 先确认当前机器类型
    echo "请确认当前机器类型："
    echo " [1] A机器（国内服务器）"
    echo " [2] B机器（海外服务器）"
    echo ""
    read -e -p "当前机器是: " current_machine

    if [ "$current_machine" != "1" ] && [ "$current_machine" != "2" ]; then
        echo "❌ 无效选择"
        read -e -p "按回车键返回..."
        return
    fi

    echo ""
    echo "请提供以下信息："
    echo ""

    # 根据机器类型获取不同信息
    local b_machine_ipv6=""
    if [ "$current_machine" == "1" ]; then
        # A机器需要输入B机器IPv6地址
        read -e -p "🌐 B机器IPv6地址: " b_machine_ipv6
        if [ -z "$b_machine_ipv6" ]; then
            echo "❌ B机器IPv6地址不能为空"
            read -e -p "按回车键返回..."
            return
        fi
    else
        # B机器自动检测本机IPv6地址
        echo "🔍 自动检测本机IPv6地址..."
        b_machine_ipv6=$(ip -6 addr show | grep 'inet6.*global' | head -1 | awk '{print $2}' | cut -d'/' -f1)
        if [ -z "$b_machine_ipv6" ]; then
            echo "⚠️  未检测到IPv6地址，请手动输入："
            read -e -p "🌐 本机IPv6地址: " b_machine_ipv6
            if [ -z "$b_machine_ipv6" ]; then
                echo "❌ IPv6地址不能为空"
                read -e -p "按回车键返回..."
                return
            fi
        else
            echo "✅ 检测到IPv6地址: $b_machine_ipv6"
        fi
    fi

    # 根据机器类型获取不同信息
    if [ "$current_machine" == "1" ]; then
        # A机器只需要端口信息
        read -e -p "📍 A机器监听端口 (如: 35812): " listen_ports
        if [ -z "$listen_ports" ]; then
            listen_ports="35812"
        fi

        read -e -p "🔌 B机器监听端口 (默认与A机器相同): " b_listen_port
        if [ -z "$b_listen_port" ]; then
            b_listen_port="$listen_ports"
        fi

        # 添加备注功能
        read -e -p "📝 备注信息 (可选，如: 双栈转发): " tunnel_remark
        if [ -z "$tunnel_remark" ]; then
            tunnel_remark="双栈隧道转发"
        fi

        echo ""
        echo "📋 A机器配置摘要："
        echo "  🌐 B机器IPv6: $b_machine_ipv6"
        echo "  📍 A机器端口: $listen_ports (IPv4监听)"
        echo "  🔌 B机器端口: $b_listen_port (IPv6监听)"
        echo "  📝 备注信息: $tunnel_remark"
        echo ""

    elif [ "$current_machine" == "2" ]; then
        # B机器需要XrayR信息
        read -e -p "🎯 XrayR节点地址 (IPv4): " xrayr_host
        if [ -z "$xrayr_host" ]; then
            echo "❌ XrayR地址不能为空"
            read -e -p "按回车键返回..."
            return
        fi

        read -e -p "🔌 XrayR节点端口: " xrayr_port
        if [ -z "$xrayr_port" ]; then
            echo "❌ XrayR端口不能为空"
            read -e -p "按回车键返回..."
            return
        fi

        read -e -p "📍 B机器监听端口 (如: 35812): " b_listen_port
        if [ -z "$b_listen_port" ]; then
            b_listen_port="35812"
        fi

        # 添加备注功能
        read -e -p "📝 备注信息 (可选，如: 双栈转发): " tunnel_remark
        if [ -z "$tunnel_remark" ]; then
            tunnel_remark="双栈隧道转发"
        fi

        echo ""
        echo "📋 B机器配置摘要："
        echo "  🎯 XrayR: $xrayr_host:$xrayr_port"
        echo "  📍 B机器端口: $b_listen_port (IPv6监听)"
        echo "  📝 备注信息: $tunnel_remark"
        echo ""

    else
        echo "❌ 无效选择"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "确认配置? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ 已取消配置"
        read -e -p "按回车键返回..."
        return
    fi

    # 生成配置文件
    echo ""
    echo "📝 生成配置文件..."

    # 备份现有配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    if [ "$current_machine" == "1" ]; then
        # A机器配置：IPv4监听，IPv6转发
        # 处理IPv6地址格式
        local b_ipv6_format
        if [[ "$b_machine_ipv6" == *:*:* ]] && [[ "$b_machine_ipv6" != \[*\] ]]; then
            b_ipv6_format="[$b_machine_ipv6]:$b_listen_port"
        else
            b_ipv6_format="$b_machine_ipv6:$b_listen_port"
        fi

        # 检查是否已有network配置
        if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
            # 如果没有network配置，添加一个
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = true

EOF
        else
            # 如果已有network配置，更新ipv6_only设置
            sed -i 's/ipv6_only = false/ipv6_only = true/g' "$CONFIG_FILE"
            if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a ipv6_only = true' "$CONFIG_FILE"
            fi
        fi

        # 为每个端口添加配置
        for port in $listen_ports; do
            cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - A机器IPv4监听端口$port
listen = "0.0.0.0:$port"
remote = "$b_ipv6_format"
EOF
        done

        echo "✅ A机器双栈配置完成！"
        echo ""
        echo "📋 A机器配置摘要："
        echo "  📍 监听端口: $listen_ports (IPv4)"
        echo "  🎯 连接目标: $b_ipv6_format (IPv6)"
        echo "  🔄 转发模式: IPv4→IPv6"
        echo "  🔐 PROXY Protocol: 发送"
        echo ""
        echo "📝 B机器配置命令："
        echo "在B机器上运行相同脚本，选择选项17 → 4，使用以下信息："
        echo "  当前机器选择: 2 (B机器)"
        echo "  B机器IPv6: $b_machine_ipv6"
        echo "  监听端口: $b_listen_port"
        echo "  备注信息: $tunnel_remark"

    elif [ "$current_machine" == "2" ]; then
        # B机器配置：IPv6监听，IPv4转发
        # 检查是否已有network配置
        if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
            # 如果没有network配置，添加一个
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = false

EOF
        else
            # 如果已有network配置，更新相关设置
            sed -i 's/accept_proxy = false/accept_proxy = true/g' "$CONFIG_FILE"
            sed -i 's/ipv6_only = true/ipv6_only = false/g' "$CONFIG_FILE"
            if ! grep -q "accept_proxy" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a accept_proxy = true' "$CONFIG_FILE"
            fi
            if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a ipv6_only = false' "$CONFIG_FILE"
            fi
        fi

        # 添加双栈监听配置（IPv6地址自动包含IPv4）
        cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - B机器双栈监听
listen = "[::]:$b_listen_port"
remote = "$xrayr_host:$xrayr_port"
EOF

        echo "✅ B机器双栈配置完成！"
        echo ""
        echo "📋 B机器配置摘要："
        echo "  📍 监听端口: $b_listen_port (IPv4+IPv6双栈)"
        echo "  🎯 转发目标: $xrayr_host:$xrayr_port (IPv4)"
        echo "  🔄 转发模式: IPv4/IPv6→IPv4"
        echo "  🔐 PROXY Protocol: 接收+发送"
        echo ""
        echo "🔥 防火墙设置："
        echo "  ufw allow $b_listen_port"
        echo "  ip6tables -A INPUT -p tcp --dport $b_listen_port -j ACCEPT"

    else
        echo "❌ 无效选择"
        read -e -p "按回车键返回..."
        return
    fi

    restart_service_prompt
}

# 纯IPv6隧道配置（IPv6监听+IPv6转发）
configure_pure_ipv6_tunnel() {
    echo ""
    echo "🌐 纯IPv6隧道配置（IPv6监听+IPv6转发）"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "纯IPv6隧道特点："
    echo "✅ A机器：用户IPv6连接，向B机器IPv6转发"
    echo "✅ B机器：IPv6监听，向XrayR转发（IPv4或IPv6）"
    echo "✅ 适合纯IPv6环境"
    echo "✅ 充分利用IPv6网络性能"
    echo "✅ 避免IPv4地址不足问题"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    echo "请提供以下信息："
    echo ""

    # 先检测当前机器类型
    echo "💡 提示：如果您在B机器上运行，可以跳过IPv6地址输入"
    echo ""
    read -e -p "🌐 B机器IPv6地址 (B机器可留空自动检测): " b_machine_ipv6

    # 如果为空，尝试自动检测
    if [ -z "$b_machine_ipv6" ]; then
        echo "🔍 自动检测本机IPv6地址..."
        b_machine_ipv6=$(ip -6 addr show | grep 'inet6.*global' | head -1 | awk '{print $2}' | cut -d'/' -f1)
        if [ -z "$b_machine_ipv6" ]; then
            echo "⚠️  未检测到IPv6地址，请手动输入："
            read -e -p "🌐 B机器IPv6地址: " b_machine_ipv6
            if [ -z "$b_machine_ipv6" ]; then
                echo "❌ IPv6地址不能为空"
                read -e -p "按回车键返回..."
                return
            fi
        else
            echo "✅ 检测到IPv6地址: $b_machine_ipv6"
        fi
    fi

    # 获取XrayR信息
    read -e -p "🎯 XrayR节点地址 (IPv4或IPv6): " xrayr_host
    if [ -z "$xrayr_host" ]; then
        echo "❌ XrayR地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 XrayR节点端口: " xrayr_port
    if [ -z "$xrayr_port" ]; then
        echo "❌ XrayR端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    # 获取端口配置
    read -e -p "📍 A机器监听端口 (如: 35812): " listen_ports
    if [ -z "$listen_ports" ]; then
        listen_ports="35812"
    fi

    read -e -p "🔌 B机器监听端口 (默认与A机器相同): " b_listen_port
    if [ -z "$b_listen_port" ]; then
        b_listen_port="$listen_ports"
    fi

    # 添加备注功能
    read -e -p "📝 备注信息 (可选，如: 纯IPv6转发): " tunnel_remark
    if [ -z "$tunnel_remark" ]; then
        tunnel_remark="纯IPv6隧道转发"
    fi

    echo ""
    echo "📋 配置摘要："
    echo "  🌐 B机器IPv6: $b_machine_ipv6"
    echo "  🎯 XrayR: $xrayr_host:$xrayr_port"
    echo "  📍 A机器端口: $listen_ports (IPv6监听)"
    echo "  🔌 B机器端口: $b_listen_port (IPv6监听)"
    echo "  📝 备注信息: $tunnel_remark"
    echo ""

    read -e -p "确认配置? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ 已取消配置"
        read -e -p "按回车键返回..."
        return
    fi

    # 生成配置文件
    echo ""
    echo "📝 生成配置文件..."

    # 处理IPv6地址格式
    local b_ipv6_format
    if [[ "$b_machine_ipv6" == *:*:* ]] && [[ "$b_machine_ipv6" != \[*\] ]]; then
        b_ipv6_format="[$b_machine_ipv6]:$b_listen_port"
    else
        b_ipv6_format="$b_machine_ipv6:$b_listen_port"
    fi

    # 处理XrayR地址格式
    local xrayr_format
    if [[ "$xrayr_host" == *:*:* ]] && [[ "$xrayr_host" != \[*\] ]]; then
        xrayr_format="[$xrayr_host]:$xrayr_port"
    else
        xrayr_format="$xrayr_host:$xrayr_port"
    fi

    # 备份现有配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # 检测当前机器类型
    echo ""
    echo "请确认当前机器类型："
    echo " [1] A机器（国内服务器）"
    echo " [2] B机器（海外服务器）"
    echo ""
    read -e -p "当前机器是: " current_machine

    case $current_machine in
        1)
            # A机器配置：IPv6监听，IPv6转发
            # 检查是否已有network配置
            if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
                # 如果没有network配置，添加一个
                cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = true

EOF
            else
                # 如果已有network配置，更新ipv6_only设置
                sed -i 's/ipv6_only = false/ipv6_only = true/g' "$CONFIG_FILE"
                if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                    sed -i '/\[network\]/a ipv6_only = true' "$CONFIG_FILE"
                fi
            fi

            # 为每个端口添加配置
            for port in $listen_ports; do
                cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - A机器IPv6监听端口$port
listen = "[::]:$port"
remote = "$b_ipv6_format"
EOF
            done

            echo "✅ A机器纯IPv6配置完成！"
            echo ""
            echo "📋 A机器配置摘要："
            echo "  📍 监听端口: $listen_ports (IPv6)"
            echo "  🎯 连接目标: $b_ipv6_format (IPv6)"
            echo "  🔄 转发模式: IPv6→IPv6"
            echo "  🔐 PROXY Protocol: 发送"
            echo ""
            echo "🔥 防火墙设置："
            echo "  ufw allow $listen_ports"
            echo "  ip6tables -A INPUT -p tcp --dport $listen_ports -j ACCEPT"
            echo ""
            echo "📝 B机器配置命令："
            echo "在B机器上运行相同脚本，选择选项17 → 5，使用以下信息："
            echo "  XrayR地址: $xrayr_host"
            echo "  XrayR端口: $xrayr_port"
            echo "  监听端口: $b_listen_port"
            echo "  备注信息: $tunnel_remark"
            ;;

        2)
            # B机器配置：IPv6监听，转发到XrayR
            # 判断XrayR是否为IPv6
            local ipv6_only_setting="false"
            if [[ "$xrayr_host" == *:*:* ]]; then
                ipv6_only_setting="true"
                echo "🔍 检测到XrayR使用IPv6地址，启用IPv6-only模式"
            else
                echo "🔍 检测到XrayR使用IPv4地址，允许IPv4转发"
            fi

            # 检查是否已有network配置
            if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
                # 如果没有network配置，添加一个
                cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = $ipv6_only_setting

EOF
            else
                # 如果已有network配置，更新相关设置
                sed -i 's/accept_proxy = false/accept_proxy = true/g' "$CONFIG_FILE"
                sed -i "s/ipv6_only = .*/ipv6_only = $ipv6_only_setting/g" "$CONFIG_FILE"
                if ! grep -q "accept_proxy" "$CONFIG_FILE"; then
                    sed -i '/\[network\]/a accept_proxy = true' "$CONFIG_FILE"
                fi
                if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                    sed -i "/\[network\]/a ipv6_only = $ipv6_only_setting" "$CONFIG_FILE"
                fi
            fi

            # 添加双栈监听配置（IPv6地址自动包含IPv4）
            cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - B机器双栈监听
listen = "[::]:$b_listen_port"
remote = "$xrayr_format"
EOF

            echo "✅ B机器纯IPv6配置完成！"
            echo ""
            echo "📋 B机器配置摘要："
            echo "  📍 监听端口: $b_listen_port (IPv4+IPv6双栈)"
            echo "  🎯 转发目标: $xrayr_format"
            echo "  🔄 转发模式: IPv4/IPv6→$(if [[ "$xrayr_host" == *:*:* ]]; then echo "IPv6"; else echo "IPv4"; fi)"
            echo "  🔐 PROXY Protocol: 接收+发送"
            echo "  🌐 IPv6-only: $ipv6_only_setting"
            echo ""
            echo "🔥 防火墙设置："
            echo "  ufw allow $b_listen_port"
            echo "  ip6tables -A INPUT -p tcp --dport $b_listen_port -j ACCEPT"
            echo ""
            echo "📝 A机器配置命令："
            echo "在A机器上运行相同脚本，选择选项17 → 5，使用以下信息："
            echo "  B机器IPv6: $b_machine_ipv6"
            echo "  监听端口: $listen_ports"
            echo "  备注信息: $tunnel_remark"
            ;;

        *)
            echo "❌ 无效选择"
            read -e -p "按回车键返回..."
            return
            ;;
    esac

    restart_service_prompt
}

# 反向双栈隧道配置（IPv6监听+IPv4转发）
configure_reverse_dual_stack_tunnel() {
    echo ""
    echo "🌐 反向双栈隧道配置（IPv6监听+IPv4转发）"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    echo "反向双栈隧道特点："
    echo "✅ A机器：用户IPv6连接，向B机器IPv4转发"
    echo "✅ B机器：IPv4监听，向XrayR转发"
    echo "✅ 适合IPv6用户访问IPv4服务器"
    echo "✅ 解决IPv6到IPv4的连接需求"
    echo ""
    echo "—————————————————————————————————————————————————————————"

    echo "请提供以下信息："
    echo ""

    # 获取B机器IPv4信息
    read -e -p "🌐 B机器IPv4地址: " b_machine_ipv4
    if [ -z "$b_machine_ipv4" ]; then
        echo "❌ B机器IPv4地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    # 检测当前机器类型
    echo ""
    echo "请确认当前机器类型："
    echo " [1] A机器（国内服务器）"
    echo " [2] B机器（海外服务器）"
    echo ""
    read -e -p "当前机器是: " current_machine

    # 根据机器类型获取不同信息
    if [ "$current_machine" == "1" ]; then
        # A机器只需要端口信息
        read -e -p "📍 A机器监听端口 (如: 35812): " listen_ports
        if [ -z "$listen_ports" ]; then
            listen_ports="35812"
        fi

        read -e -p "🔌 B机器监听端口 (默认与A机器相同): " b_listen_port
        if [ -z "$b_listen_port" ]; then
            b_listen_port="$listen_ports"
        fi

        # 添加备注功能
        read -e -p "📝 备注信息 (可选，如: IPv6用户转发): " tunnel_remark
        if [ -z "$tunnel_remark" ]; then
            tunnel_remark="反向双栈隧道转发"
        fi

        echo ""
        echo "📋 A机器配置摘要："
        echo "  🌐 B机器IPv4: $b_machine_ipv4"
        echo "  📍 A机器端口: $listen_ports (IPv6监听)"
        echo "  🔌 B机器端口: $b_listen_port (IPv4监听)"
        echo "  📝 备注信息: $tunnel_remark"
        echo ""

    elif [ "$current_machine" == "2" ]; then
        # B机器需要XrayR信息
        read -e -p "🎯 XrayR节点地址: " xrayr_host
        if [ -z "$xrayr_host" ]; then
            echo "❌ XrayR地址不能为空"
            read -e -p "按回车键返回..."
            return
        fi

        read -e -p "🔌 XrayR节点端口: " xrayr_port
        if [ -z "$xrayr_port" ]; then
            echo "❌ XrayR端口不能为空"
            read -e -p "按回车键返回..."
            return
        fi

        read -e -p "📍 B机器监听端口 (如: 35812): " b_listen_port
        if [ -z "$b_listen_port" ]; then
            b_listen_port="35812"
        fi

        # 添加备注功能
        read -e -p "📝 备注信息 (可选，如: IPv6用户转发): " tunnel_remark
        if [ -z "$tunnel_remark" ]; then
            tunnel_remark="反向双栈隧道转发"
        fi

        echo ""
        echo "📋 B机器配置摘要："
        echo "  🎯 XrayR: $xrayr_host:$xrayr_port"
        echo "  📍 B机器端口: $b_listen_port (IPv4监听)"
        echo "  📝 备注信息: $tunnel_remark"
        echo ""

    else
        echo "❌ 无效选择"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "确认配置? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ 已取消配置"
        read -e -p "按回车键返回..."
        return
    fi

    # 生成配置文件
    echo ""
    echo "📝 生成配置文件..."

    # 备份现有配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    if [ "$current_machine" == "1" ]; then
        # A机器配置：IPv6监听，IPv4转发
        # 检查是否已有network配置
        if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
            # 如果没有network配置，添加一个
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = false

EOF
        else
            # 如果已有network配置，更新ipv6_only设置
            sed -i 's/ipv6_only = true/ipv6_only = false/g' "$CONFIG_FILE"
            if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a ipv6_only = false' "$CONFIG_FILE"
            fi
        fi

        # 为每个端口添加配置
        for port in $listen_ports; do
            cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - A机器IPv6监听端口$port
listen = "[::]:$port"
remote = "$b_machine_ipv4:$b_listen_port"
EOF
        done

        echo "✅ A机器反向双栈配置完成！"
        echo ""
        echo "📋 A机器配置摘要："
        echo "  📍 监听端口: $listen_ports (IPv6)"
        echo "  🎯 连接目标: $b_machine_ipv4:$b_listen_port (IPv4)"
        echo "  🔄 转发模式: IPv6→IPv4"
        echo "  🔐 PROXY Protocol: 发送"
        echo ""
        echo "🔥 防火墙设置："
        echo "  ufw allow $listen_ports"
        echo "  ip6tables -A INPUT -p tcp --dport $listen_ports -j ACCEPT"
        echo ""
        echo "📝 B机器配置命令："
        echo "在B机器上运行相同脚本，选择选项17 → 6，使用以下信息："
        echo "  当前机器选择: 2 (B机器)"
        echo "  B机器IPv4: $b_machine_ipv4"
        echo "  监听端口: $b_listen_port"
        echo "  备注信息: $tunnel_remark"

    elif [ "$current_machine" == "2" ]; then
        # B机器配置：IPv4监听，转发到XrayR
        # 处理XrayR地址格式
        local xrayr_format
        if [[ "$xrayr_host" == *:*:* ]] && [[ "$xrayr_host" != \[*\] ]]; then
            xrayr_format="[$xrayr_host]:$xrayr_port"
        else
            xrayr_format="$xrayr_host:$xrayr_port"
        fi

        # 检查是否已有network配置
        if ! grep -q "^\[network\]" "$CONFIG_FILE" 2>/dev/null; then
            # 如果没有network配置，添加一个
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
ipv6_only = false

EOF
        else
            # 如果已有network配置，更新相关设置
            sed -i 's/accept_proxy = false/accept_proxy = true/g' "$CONFIG_FILE"
            sed -i 's/ipv6_only = true/ipv6_only = false/g' "$CONFIG_FILE"
            if ! grep -q "accept_proxy" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a accept_proxy = true' "$CONFIG_FILE"
            fi
            if ! grep -q "ipv6_only" "$CONFIG_FILE"; then
                sed -i '/\[network\]/a ipv6_only = false' "$CONFIG_FILE"
            fi
        fi

        # 添加endpoint配置
        cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $tunnel_remark - B机器IPv4监听
listen = "0.0.0.0:$b_listen_port"
remote = "$xrayr_format"
EOF

        echo "✅ B机器反向双栈配置完成！"
        echo ""
        echo "📋 B机器配置摘要："
        echo "  📍 监听端口: $b_listen_port (IPv4)"
        echo "  🎯 转发目标: $xrayr_format"
        echo "  🔄 转发模式: IPv4→$(if [[ "$xrayr_host" == *:*:* ]]; then echo "IPv6"; else echo "IPv4"; fi)"
        echo "  🔐 PROXY Protocol: 接收+发送"
        echo ""
        echo "🔥 防火墙设置："
        echo "  ufw allow $b_listen_port"

    else
        echo "❌ 无效选择"
        read -e -p "按回车键返回..."
        return
    fi

    restart_service_prompt
}

# WS客户端配置（A机器）
configure_ws_client_only() {
    echo ""
    echo "🔧 A机器WS客户端配置"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "🌐 B机器IP地址: " server_ip
    if [ -z "$server_ip" ]; then
        echo "❌ 服务器IP不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 B机器WS端口 (默认8080): " server_port
    if [ -z "$server_port" ]; then
        server_port="8080"
    fi

    read -e -p "📍 本地监听端口 (如: 29731): " local_port
    if [ -z "$local_port" ]; then
        local_port="29731"
    fi

    local fake_domain="www.cloudflare.com"
    read -e -p "🎭 伪装域名 (默认: $fake_domain): " custom_domain
    if [ -n "$custom_domain" ]; then
        fake_domain="$custom_domain"
    fi

    read -e -p "📂 WebSocket路径 (默认/ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    read -e -p "📝 备注信息 (可选): " ws_remark
    if [ -z "$ws_remark" ]; then
        ws_remark="WS客户端"
    fi

    # 验证端口号
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [ "$local_port" -lt 1 ] || [ "$local_port" -gt 65535 ]; then
        echo "❌ 端口号无效"
        read -e -p "按回车键返回..."
        return
    fi

    # 检查端口冲突
    if grep -q "listen = \"0.0.0.0:$local_port\"" "$CONFIG_FILE" 2>/dev/null; then
        echo "❌ 端口 $local_port 已在配置中使用"
        read -e -p "按回车键返回..."
        return
    fi

    # 添加WS客户端配置
    cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $ws_remark
listen = "0.0.0.0:$local_port"
remote = "$server_ip:$server_port"
transport = "ws;host=$fake_domain;path=$ws_path"
EOF

    echo ""
    echo "✅ WS客户端配置完成！"
    echo ""
    echo "📋 配置摘要："
    echo "  📍 监听端口: $local_port"
    echo "  🎯 连接目标: $server_ip:$server_port"
    echo "  🎭 伪装域名: $fake_domain"
    echo "  📂 WebSocket路径: $ws_path"

    restart_service_prompt
}

# WS服务端配置（B机器）
configure_ws_server_only() {
    echo ""
    echo "🔧 B机器WS服务端配置"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    read -e -p "🎯 XrayR节点地址: " xrayr_host
    if [ -z "$xrayr_host" ]; then
        echo "❌ XrayR地址不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "🔌 XrayR节点端口: " xrayr_port
    if [ -z "$xrayr_port" ]; then
        echo "❌ XrayR端口不能为空"
        read -e -p "按回车键返回..."
        return
    fi

    read -e -p "📍 WS监听端口 (默认8080): " listen_port
    if [ -z "$listen_port" ]; then
        listen_port="8080"
    fi

    local fake_domain="www.cloudflare.com"
    read -e -p "🎭 伪装域名 (默认: $fake_domain): " custom_domain
    if [ -n "$custom_domain" ]; then
        fake_domain="$custom_domain"
    fi

    read -e -p "📂 WebSocket路径 (默认/ws): " ws_path
    if [ -z "$ws_path" ]; then
        ws_path="/ws"
    fi

    read -e -p "📝 备注信息 (可选): " ws_remark
    if [ -z "$ws_remark" ]; then
        ws_remark="WS服务端"
    fi

    # 验证端口号
    if ! [[ "$listen_port" =~ ^[0-9]+$ ]] || [ "$listen_port" -lt 1 ] || [ "$listen_port" -gt 65535 ]; then
        echo "❌ 端口号无效"
        read -e -p "按回车键返回..."
        return
    fi

    # 检查端口冲突
    if grep -q "listen = \"0.0.0.0:$listen_port\"" "$CONFIG_FILE" 2>/dev/null; then
        echo "❌ 端口 $listen_port 已在配置中使用"
        read -e -p "按回车键返回..."
        return
    fi

    # 处理IPv6地址格式
    local target_format
    if [[ "$xrayr_host" == *:*:* ]] && [[ "$xrayr_host" != \[*\] ]]; then
        target_format="[$xrayr_host]:$xrayr_port"
    else
        target_format="$xrayr_host:$xrayr_port"
    fi

    # 添加WS服务端配置
    cat >> "$CONFIG_FILE" << EOF

[[endpoints]]
# 备注: $ws_remark
listen = "0.0.0.0:$listen_port"
remote = "$target_format"
transport = "ws;host=$fake_domain;path=$ws_path"
EOF

    echo ""
    echo "✅ WS服务端配置完成！"
    echo ""
    echo "📋 配置摘要："
    echo "  📍 监听端口: $listen_port"
    echo "  🎯 转发目标: $target_format"
    echo "  🎭 伪装域名: $fake_domain"
    echo "  📂 WebSocket路径: $ws_path"
    echo ""
    echo "🔥 防火墙提醒："
    echo "  ufw allow $listen_port"

    restart_service_prompt
}

# 查看传输层配置
show_transport_config() {
    clear
    echo "🌐 传输层配置状态"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 配置文件不存在"
        read -e -p "按回车键返回..."
        return
    fi

    echo "📋 当前传输层配置："
    echo ""
    echo "序号 | 监听端口        | 转发地址                     | 传输类型     | 备注"
    echo "—————————————————————————————————————————————————————————————————————————————————"

    local index=1
    local current_remark=""
    local current_transport=""
    local in_endpoint=false
    local found_transport=false

    local current_listen=""
    local current_remote=""

    while IFS= read -r line; do
        # 检查备注行
        if [[ "$line" =~ ^#.*备注: ]]; then
            current_remark=$(echo "$line" | sed 's/^#.*备注: *//')
        # 检查endpoints开始
        elif [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
            in_endpoint=true
            current_transport=""
            current_listen=""
            current_remote=""
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            current_listen=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查remote行
        elif [[ "$line" =~ ^remote.*= ]] && [ "$in_endpoint" = true ]; then
            current_remote=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查transport行
        elif [[ "$line" =~ ^transport.*= ]] && [ "$in_endpoint" = true ]; then
            current_transport=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查空行或下一个section，表示当前endpoint结束
        elif [[ "$line" =~ ^$ ]] || [[ "$line" =~ ^\[ ]] && [ "$in_endpoint" = true ]; then
            if [ -n "$current_listen" ] && [ -n "$current_remote" ]; then
                # 解析传输类型
                local transport_type="TCP"
                if [[ "$current_transport" == *"ws"* ]] && [[ "$current_transport" == *"tls"* ]]; then
                    transport_type="WSS"
                elif [[ "$current_transport" == *"ws"* ]]; then
                    transport_type="WebSocket"
                elif [[ "$current_transport" == *"tls"* ]]; then
                    transport_type="TLS"
                fi

                printf " %-3s | %-15s | %-28s | %-12s | %-15s\n" "$index" "$current_listen" "$current_remote" "$transport_type" "$current_remark"
                found_transport=true
                index=$((index + 1))
            fi

            # 重置状态
            in_endpoint=false
            current_remark=""
            current_transport=""
            current_listen=""
            current_remote=""
        fi
    done < "$CONFIG_FILE"

    # 处理文件末尾的最后一个endpoint
    if [ "$in_endpoint" = true ] && [ -n "$current_listen" ] && [ -n "$current_remote" ]; then
        # 解析传输类型
        local transport_type="TCP"
        if [[ "$current_transport" == *"ws"* ]] && [[ "$current_transport" == *"tls"* ]]; then
            transport_type="WSS"
        elif [[ "$current_transport" == *"ws"* ]]; then
            transport_type="WebSocket"
        elif [[ "$current_transport" == *"tls"* ]]; then
            transport_type="TLS"
        fi

        printf " %-3s | %-15s | %-28s | %-12s | %-15s\n" "$index" "$current_listen" "$current_remote" "$transport_type" "$current_remark"
        found_transport=true
    fi

    if [ "$found_transport" = false ] && [ $index -eq 1 ]; then
        echo "暂无传输层配置"
    fi

    echo "—————————————————————————————————————————————————————————————————————————————————"
    echo ""
    echo "📖 传输类型说明："
    echo "  • TCP: 普通TCP转发"
    echo "  • WebSocket: WebSocket协议，可穿透HTTP代理"
    echo "  • TLS: TLS加密传输"
    echo "  • WSS: WebSocket over TLS，加密的WebSocket"
    echo ""

    read -e -p "按回车键返回..."
}

# 重启服务提示
restart_service_prompt() {
    read -e -p "是否立即重启服务以应用配置? (Y/n，默认Y): " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        echo "🔄 正在重启Realm服务..."
        if systemctl restart realm 2>/dev/null; then
            sleep 2
            if systemctl is-active --quiet realm; then
                echo "✅ 服务重启成功，配置已生效"
            else
                echo "⚠️  服务重启完成，但状态检查异常"
                echo "💡 配置已保存，请手动检查服务状态"
            fi
        else
            echo "❌ 服务重启失败，请检查配置文件"
            echo ""
            echo "🔍 错误日志："
            journalctl -u realm --no-pager -l | tail -5
        fi
    else
        echo "⚠️  配置已保存，但未重启服务"
        echo "💡 请手动重启服务以应用配置"
    fi

    read -e -p "按回车键返回..."
}

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
    echo "请选择操作："
    echo " [1] 确认恢复"
    echo " [0] 取消恢复"
    echo ""
    read -e -p "请选择 (1/0): " confirm

    if [ "$confirm" = "1" ]; then
        # 备份当前配置
        if [ -f "$CONFIG_FILE" ]; then
            cp "$CONFIG_FILE" "${CONFIG_FILE}.before_restore.$(date +%Y%m%d_%H%M%S)"
            echo "✅ 当前配置已备份"
        fi

        # 恢复配置
        cp "$selected_file" "$CONFIG_FILE"
        echo "✅ 配置文件已恢复"

        # 询问是否重启服务
        read -e -p "是否立即重启服务以应用配置? (Y/n，默认Y): " restart_confirm
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

# 更新脚本
update_script() {
    clear
    echo "🔄 更新 Realm 管理脚本"
    echo "—————————————————————————————————————————————————————————"
    echo ""

    # 脚本信息
    local SCRIPT_URL="https://raw.githubusercontent.com/q42602736/realm/main/install.sh"
    local SCRIPT_NAME="realm-manager.sh"
    local CURRENT_SCRIPT="$0"

    echo "📋 更新信息："
    echo "  🔗 源地址: $SCRIPT_URL"
    echo "  📁 当前脚本: $CURRENT_SCRIPT"
    echo ""

    # 如果还没有选择代理，先选择
    if [ -z "$SELECTED_PROXY" ]; then
        echo "🚀 选择下载加速方式："
        select_github_proxy
    fi

    echo "🔍 检查更新..."

    # 构建下载URL
    local download_url=$(build_download_url "$SCRIPT_URL")

    # 下载新脚本到临时文件
    local temp_script="/tmp/realm-manager-new.sh"

    echo "📥 正在下载最新版本..."
    echo "   下载地址: $download_url"

    if wget --progress=bar:force -O "$temp_script" "$download_url" 2>&1; then
        echo ""
        echo "✅ 下载成功"

        # 验证下载的文件
        if [ -f "$temp_script" ] && [ -s "$temp_script" ]; then
            # 检查文件是否为有效的shell脚本
            if head -1 "$temp_script" | grep -q "#!/bin/bash"; then
                echo "✅ 脚本文件验证成功"

                # 显示文件信息
                local new_size=$(ls -lh "$temp_script" | awk '{print $5}')
                local current_size=$(ls -lh "$CURRENT_SCRIPT" | awk '{print $5}')

                echo ""
                echo "📊 文件对比："
                echo "  当前版本大小: $current_size"
                echo "  新版本大小: $new_size"
                echo ""

                # 确认更新
                echo "⚠️  确认更新脚本？"
                echo "   • 当前脚本将被备份"
                echo "   • 新脚本将替换当前脚本"
                echo "   • 脚本将自动重启"
                echo ""
                echo "请选择操作："
                echo " [1] 确认更新"
                echo " [0] 取消更新"
                echo ""
                read -e -p "请选择 (1/0): " confirm

                if [ "$confirm" = "1" ]; then
                    # 备份当前脚本
                    local backup_script="${CURRENT_SCRIPT}.backup.$(date +%Y%m%d_%H%M%S)"
                    cp "$CURRENT_SCRIPT" "$backup_script"
                    echo "✅ 当前脚本已备份到: $backup_script"

                    # 替换脚本
                    cp "$temp_script" "$CURRENT_SCRIPT"
                    chmod +x "$CURRENT_SCRIPT"

                    echo "✅ 脚本更新成功"
                    echo ""
                    echo "🔄 正在重启脚本..."
                    sleep 2

                    # 清理临时文件
                    rm -f "$temp_script"

                    # 重新执行脚本
                    exec "$CURRENT_SCRIPT"
                else
                    echo "❌ 已取消更新"
                    rm -f "$temp_script"
                fi
            else
                echo "❌ 下载的文件不是有效的shell脚本"
                rm -f "$temp_script"
            fi
        else
            echo "❌ 下载的文件无效或为空"
            rm -f "$temp_script"
        fi
    else
        echo ""
        echo "❌ 下载失败"
        echo ""
        echo "可能的原因："
        echo "• 网络连接问题"
        echo "• GitHub访问受限"
        echo "• 代理服务器问题"
        echo ""
        echo "建议："
        echo "1. 检查网络连接"
        echo "2. 尝试更换GitHub代理"
        echo "3. 稍后再试"

        rm -f "$temp_script"
    fi

    read -e -p "按回车键返回..."
}

# 主循环
while true; do
    show_menu
    read -e -p "请选择功能 [0-25]: " choice

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
        14) configure_websocket ;;
        15) configure_tls ;;
        16) configure_wss ;;
        17) configure_ws_tunnel ;;
        18) show_transport_config ;;
        19) show_realtime_logs ;;
        20) show_error_logs ;;
        21) show_connection_stats ;;
        22) test_network_connectivity ;;
        23) backup_config ;;
        24) restore_config ;;
        25) update_script ;;
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
            echo "🌐 传输层功能："
            echo "   • WebSocket: 穿透HTTP代理和防火墙"
            echo "   • TLS: 提供传输层加密保护"
            echo "   • WSS: 加密的WebSocket连接"
            echo ""
            echo "📞 如有问题，请检查："
            echo "   • A机器: send_proxy=true, accept_proxy=false"
            echo "   • B机器: send_proxy=true, accept_proxy=true"
            echo "   • XrayR: 启用PROXY Protocol接收"
            echo ""
            echo "🔄 脚本更新："
            echo "   • 使用菜单选项24可以更新到最新版本"
            echo "   • 支持GitHub加速下载"
            echo "   • 自动备份当前版本"
            echo ""
            echo "再见！👋"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo "❌ 无效选项: $choice"
            echo "请输入 0-25 之间的数字"
            sleep 2
            ;;
    esac
done
