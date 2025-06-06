#!/bin/bash
# Realm 修复版脚本 - 修复语法错误
# 基于原版脚本，修复sed和变量赋值问题

# 设置删除键行为
stty erase "^?"

# 初始化变量
SELECTED_PROXY=""

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

# 显示菜单
show_menu() {
    clear
    echo " "
    echo " Realm 转发管理脚本 (修复版)"
    echo " ———————————— 支持GitHub加速 ————————————"
    echo " "
    echo "—————————————————————"
    echo " 1. 安装 Realm"
    echo " 2. 添加转发规则"
    echo " 3. 查看转发规则"
    echo " 4. 删除转发规则"
    echo " 5. 启动服务"
    echo " 6. 停止服务"
    echo " 7. 重启服务"
    echo " 8. 配置PROXY Protocol"
    echo " 9. 更换GitHub代理"
    echo " 10. 卸载 Realm"
    echo " 0. 退出"
    echo "—————————————————————"
    echo ""
    echo -n "Realm状态: "
    check_realm_status
    echo -n "服务状态: "
    check_service_status
    
    if [ -n "$SELECTED_PROXY" ]; then
        echo -e "GitHub代理: \\033[0;32m${SELECTED_PROXY}\\033[0m"
    else
        echo -e "GitHub代理: \\033[0;33m直连\\033[0m"
    fi
}

# 安装Realm
install_realm() {
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
            echo "✅ Realm安装成功"
        else
            echo "❌ Realm安装失败"
            return 1
        fi
    else
        echo "❌ Realm下载失败"
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
    if [ ! -f /root/realm/config.toml ]; then
        cat > /root/realm/config.toml << 'EOF'
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
    rm -f realm.tar.gz
    
    read -e -p "按回车键返回..."
}

# 添加转发规则
add_forward() {
    clear
    echo "添加 Realm 转发规则"
    echo "—————————————————————"
    
    read -e -p "请输入本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "未输入端口，返回主菜单。"
        read -e -p "按回车键返回..."
        return
    fi
    
    read -e -p "请输入需要转发的IP: " ip
    if [ -z "$ip" ]; then
        echo "未输入IP，返回主菜单。"
        read -e -p "按回车键返回..."
        return
    fi
    
    read -e -p "请输入需要转发端口: " port
    if [ -z "$port" ]; then
        echo "未输入转发端口，返回主菜单。"
        read -e -p "按回车键返回..."
        return
    fi
    
    read -e -p "请输入备注(可为空): " remark
    
    # 处理IPv6地址
    if [[ "$ip" == *:*:* ]] && [[ "$ip" != \[*\] ]]; then
        remote_format="[$ip]:$port"
    else
        remote_format="$ip:$port"
    fi
    
    # 添加到配置文件
    cat >> /root/realm/config.toml << EOF

[[endpoints]]
# 备注: $remark
listen = "[::]:$local_port"
remote = "$remote_format"
EOF
    
    echo "✅ 转发规则已添加"
    systemctl restart realm 2>/dev/null
    echo "✅ 服务已重启"
    
    read -e -p "按回车键返回..."
}

# 查看转发规则（修复版）
show_all_conf() {
    clear
    echo "当前 Realm 转发规则"
    echo "—————————————————————————————————————————————————————————————————"
    
    if [ ! -f "/root/realm/config.toml" ]; then
        echo "配置文件不存在，请先安装Realm。"
        read -e -p "按回车键返回..."
        return
    fi
    
    # 简化的规则显示
    local index=1
    local in_endpoint=false
    local listen_port=""
    local remote_addr=""
    local remark=""
    
    while IFS= read -r line; do
        # 检查是否是备注行
        if [[ "$line" =~ ^#.*备注: ]]; then
            remark=$(echo "$line" | sed 's/^#.*备注: *//')
        # 检查是否是endpoints开始
        elif [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
            in_endpoint=true
            listen_port=""
            remote_addr=""
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查remote行
        elif [[ "$line" =~ ^remote.*= ]] && [ "$in_endpoint" = true ]; then
            remote_addr=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
            
            # 显示这条规则
            printf " %-3s | %-15s | %-35s | %-20s\n" "$index" "$listen_port" "$remote_addr" "$remark"
            echo "—————————————————————————————————————————————————————————————————"
            
            # 重置变量
            index=$((index + 1))
            in_endpoint=false
            remark=""
        fi
    done < /root/realm/config.toml
    
    if [ $index -eq 1 ]; then
        echo "没有发现任何转发规则。"
    fi

    read -e -p "按回车键返回..."
}

# 删除转发规则
delete_forward() {
    clear
    echo "删除 Realm 转发规则"
    echo "—————————————————————————————————————————————————————————————————"

    if [ ! -f "/root/realm/config.toml" ]; then
        echo "配置文件不存在，请先安装Realm。"
        read -e -p "按回车键返回..."
        return
    fi

    # 显示当前规则
    local index=1
    local in_endpoint=false
    local listen_port=""
    local remote_addr=""
    local remark=""
    declare -a rule_lines=()
    declare -a rule_info=()

    echo "当前转发规则："
    echo ""

    while IFS= read -r line; do
        local line_num=$((index))

        # 检查是否是备注行
        if [[ "$line" =~ ^#.*备注: ]]; then
            remark=$(echo "$line" | sed 's/^#.*备注: *//')
        # 检查是否是endpoints开始
        elif [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
            in_endpoint=true
            listen_port=""
            remote_addr=""
            rule_start_line=$line_num
        # 检查listen行
        elif [[ "$line" =~ ^listen.*= ]] && [ "$in_endpoint" = true ]; then
            listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        # 检查remote行
        elif [[ "$line" =~ ^remote.*= ]] && [ "$in_endpoint" = true ]; then
            remote_addr=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')

            # 保存规则信息
            rule_info+=("$listen_port|$remote_addr|$remark")
            rule_lines+=("$rule_start_line")

            # 显示这条规则
            printf " [%s] %-15s → %-35s (%s)\n" "${#rule_info[@]}" "$listen_port" "$remote_addr" "$remark"

            # 重置变量
            in_endpoint=false
            remark=""
        fi

        index=$((index + 1))
    done < /root/realm/config.toml

    if [ ${#rule_info[@]} -eq 0 ]; then
        echo "没有发现任何转发规则。"
        read -e -p "按回车键返回..."
        return
    fi

    echo ""
    echo "—————————————————————————————————————————————————————————————————"
    read -e -p "请输入要删除的规则编号 (1-${#rule_info[@]}) 或按回车返回: " choice

    if [ -z "$choice" ]; then
        return
    fi

    # 验证输入
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#rule_info[@]} ]; then
        echo "❌ 无效的规则编号"
        read -e -p "按回车键返回..."
        return
    fi

    # 获取选中规则的信息
    local selected_rule="${rule_info[$((choice-1))]}"
    local listen_part=$(echo "$selected_rule" | cut -d'|' -f1)
    local remote_part=$(echo "$selected_rule" | cut -d'|' -f2)
    local remark_part=$(echo "$selected_rule" | cut -d'|' -f3)

    echo ""
    echo "确认删除以下规则？"
    echo "  监听端口: $listen_part"
    echo "  转发地址: $remote_part"
    echo "  备注: $remark_part"
    echo ""
    read -e -p "确认删除? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 备份配置文件
        cp /root/realm/config.toml /root/realm/config.toml.backup.$(date +%Y%m%d_%H%M%S)

        # 删除规则（删除整个endpoints块）
        # 创建临时文件
        local temp_file="/tmp/realm_config_temp.toml"
        local skip_block=false
        local current_listen=""

        while IFS= read -r line; do
            if [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
                skip_block=false
                current_listen=""
                # 开始一个新的endpoints块，先保存这一行
                echo "$line" >> "$temp_file"
            elif [[ "$line" =~ ^listen.*= ]] && [ "$skip_block" = false ]; then
                current_listen=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
                if [ "$current_listen" = "$listen_part" ]; then
                    # 找到要删除的规则，开始跳过
                    skip_block=true
                    # 删除刚才添加的[[endpoints]]行
                    head -n -1 "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file"
                else
                    echo "$line" >> "$temp_file"
                fi
            elif [ "$skip_block" = true ]; then
                # 跳过当前块的所有行，直到遇到下一个[[endpoints]]或文件结束
                if [[ "$line" =~ ^\[\[endpoints\]\] ]]; then
                    skip_block=false
                    echo "$line" >> "$temp_file"
                fi
                # 其他行都跳过
            else
                echo "$line" >> "$temp_file"
            fi
        done < /root/realm/config.toml

        # 替换原配置文件
        mv "$temp_file" /root/realm/config.toml

        echo "✅ 规则删除成功"
        echo "✅ 原配置已备份"

        # 重启服务
        systemctl restart realm 2>/dev/null
        echo "✅ 服务已重启"
    else
        echo "已取消删除"
    fi

    read -e -p "按回车键返回..."
}

# 启动服务
start_service() {
    echo "启动Realm服务..."
    systemctl enable realm
    systemctl start realm

    sleep 2
    if systemctl is-active --quiet realm; then
        echo "✅ Realm服务启动成功"
    else
        echo "❌ Realm服务启动失败"
        echo "查看错误日志:"
        journalctl -u realm --no-pager -l | tail -10
    fi

    read -e -p "按回车键返回..."
}

# 停止服务
stop_service() {
    echo "停止Realm服务..."
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
    echo "重启Realm服务..."
    systemctl restart realm

    sleep 2
    if systemctl is-active --quiet realm; then
        echo "✅ Realm服务重启成功"
    else
        echo "❌ Realm服务重启失败"
        echo "查看错误日志:"
        journalctl -u realm --no-pager -l | tail -10
    fi

    read -e -p "按回车键返回..."
}

# 配置PROXY Protocol
configure_proxy_protocol() {
    clear
    echo "PROXY Protocol 配置"
    echo "—————————————————————"
    echo ""
    echo "当前配置："
    if [ -f "/root/realm/config.toml" ]; then
        grep -E "(send_proxy|accept_proxy)" /root/realm/config.toml | head -2
    else
        echo "配置文件不存在"
    fi
    echo ""
    echo "配置选项："
    echo " [1] A机器 - 发送PROXY Protocol"
    echo " [2] B机器 - 接收PROXY Protocol"
    echo " [3] B机器 - 接收+发送PROXY Protocol"
    echo " [4] 禁用PROXY Protocol"
    echo " [0] 返回主菜单"
    echo "—————————————————————"

    read -e -p "请选择: " choice

    case $choice in
        1)
            sed -i 's/send_proxy = .*/send_proxy = true/' /root/realm/config.toml
            sed -i 's/accept_proxy = .*/accept_proxy = false/' /root/realm/config.toml
            echo "✅ 已配置为发送PROXY Protocol"
            systemctl restart realm
            ;;
        2)
            sed -i 's/send_proxy = .*/send_proxy = false/' /root/realm/config.toml
            sed -i 's/accept_proxy = .*/accept_proxy = true/' /root/realm/config.toml
            echo "✅ 已配置为接收PROXY Protocol"
            systemctl restart realm
            ;;
        3)
            sed -i 's/send_proxy = .*/send_proxy = true/' /root/realm/config.toml
            sed -i 's/accept_proxy = .*/accept_proxy = true/' /root/realm/config.toml
            echo "✅ 已配置为接收+发送PROXY Protocol"
            systemctl restart realm
            ;;
        4)
            sed -i 's/send_proxy = .*/send_proxy = false/' /root/realm/config.toml
            sed -i 's/accept_proxy = .*/accept_proxy = false/' /root/realm/config.toml
            echo "✅ 已禁用PROXY Protocol"
            systemctl restart realm
            ;;
        0)
            return
            ;;
        *)
            echo "无效选择"
            ;;
    esac

    if [ "$choice" != "0" ]; then
        echo "服务已重启以应用配置"
        read -e -p "按回车键返回..."
    fi
}

# 更换GitHub代理
change_github_proxy() {
    echo "当前GitHub代理设置："
    if [ -n "$SELECTED_PROXY" ]; then
        echo "  $SELECTED_PROXY"
    else
        echo "  直连GitHub"
    fi
    echo ""

    read -e -p "是否要更换? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        select_github_proxy
    fi
}

# 卸载Realm
uninstall_realm() {
    echo "确认要卸载Realm吗？这将删除所有配置。"
    read -e -p "确认卸载? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop realm 2>/dev/null
        systemctl disable realm 2>/dev/null
        rm -f /etc/systemd/system/realm.service
        systemctl daemon-reload
        rm -rf /root/realm
        echo "✅ Realm已卸载"
    else
        echo "已取消"
    fi

    read -e -p "按回车键返回..."
}

# 主循环
while true; do
    show_menu
    read -e -p "请选择 [0-10]: " choice

    case $choice in
        1) install_realm ;;
        2) add_forward ;;
        3) show_all_conf ;;
        4) delete_forward ;;
        5) start_service ;;
        6) stop_service ;;
        7) restart_service ;;
        8) configure_proxy_protocol ;;
        9) change_github_proxy ;;
        10) uninstall_realm ;;
        0)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效选择"
            sleep 1
            ;;
    esac
done
