#!/bin/bash
# EZRealm增强版 - 支持PROXY Protocol
# 基于原版EZRealm脚本，添加PROXY Protocol功能
# 修改by：AI Assistant 修改日期：2025/01/16

# 设置删除键行为
stty erase "^?"

# 检查Realm是否已安装
if [ -f "/root/realm/realm" ]; then
    echo "检测到Realm已安装。"
    realm_status="已安装"
    realm_status_color="\\033[0;32m" # 绿色
else
    echo "Realm未安装。"
    realm_status="未安装"
    realm_status_color="\\033[0;31m" # 红色
fi

# 检查Realm服务状态
check_realm_service_status() {
    # 检查转发规则数量
    local rule_count=$(grep -c '^\\[\\[endpoints\\]\\]' /root/realm/config.toml 2>/dev/null || echo "0")
    if systemctl is-active --quiet realm && [ "$rule_count" -gt 0 ]; then
        echo -e "\\033[0;32m启用\\033[0m" # 绿色
    else
        echo -e "\\033[0;31m未启用\\033[0m" # 红色
    fi
}

# 检查PROXY Protocol状态
check_proxy_protocol_status() {
    if [ -f "/root/realm/config.toml" ]; then
        local send_proxy=$(grep "send_proxy = true" /root/realm/config.toml 2>/dev/null)
        local accept_proxy=$(grep "accept_proxy = true" /root/realm/config.toml 2>/dev/null)
        
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

# 显示菜单的函数
show_menu() {
    clear
    echo " "
    echo " 欢迎使用Realm一键转发脚本 (PROXY Protocol增强版)"
    echo " ———————————— Realm版本v2.7.0 ————————————"
    echo " 增强by：AI Assistant 增强日期：2025/01/16"
    echo " "
    echo "—————————————————————"
    echo " 1. 安装 Realm"
    echo "—————————————————————"
    echo " 2. 添加 Realm 转发规则"
    echo " 3. 查看 Realm 转发规则"
    echo " 4. 修改 Realm 转发规则"
    echo " 5. 删除 Realm 转发规则"
    echo "—————————————————————"
    echo " 6. 启动 Realm 服务"
    echo " 7. 停止 Realm 服务"
    echo " 8. 重启 Realm 服务"
    echo "—————————————————————"
    echo " 9. 配置 PROXY Protocol"  # 新增功能
    echo " 10. 查看 PROXY Protocol 状态"  # 新增功能
    echo "—————————————————————"
    echo " 11. 卸载 Realm"
    echo "—————————————————————"
    echo " 12. 定时重启任务"
    echo "—————————————————————"
    echo " 13. 导出转发规则"
    echo " 14. 导入转发规则"
    echo "—————————————————————"
    echo " 0. 退出脚本"
    echo "—————————————————————"
    echo " "
    echo -e "Realm 状态：${realm_status_color}${realm_status}\\033[0m"
    echo -n "Realm 转发状态："
    check_realm_service_status
    echo -n "PROXY Protocol 状态："
    check_proxy_protocol_status
}

# 部署环境的函数（增强版）
deploy_realm() {
    mkdir -p /root/realm
    cd /root/realm
    
    echo "正在下载最新版本的Realm..."
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
    
    # 下载最新版本（支持PROXY Protocol）
    wget -O realm.tar.gz "https://github.com/zhboner/realm/releases/latest/download/realm-${REALM_ARCH}.tar.gz"
    tar -xvf realm.tar.gz
    chmod +x realm
    
    # 创建服务文件
    echo "[Unit]
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
WantedBy=multi-user.target" > /etc/systemd/system/realm.service
    
    systemctl daemon-reload
    
    # 服务启动后，检查config.toml是否存在，如果不存在则创建
    if [ ! -f /root/realm/config.toml ]; then
        touch /root/realm/config.toml
    fi
    
    # 创建增强的网络配置
    create_enhanced_network_config
    
    # 更新realm状态变量
    realm_status="已安装"
    realm_status_color="\\033[0;32m" # 绿色
    echo "✅ Realm部署完成，已支持PROXY Protocol功能。"
}

# 创建增强的网络配置
create_enhanced_network_config() {
    # 检查 config.toml 中是否已经包含 [network] 配置块
    network_count=$(grep -c '^\\[network\\]' /root/realm/config.toml)
    if [ "$network_count" -eq 0 ]; then
        # 如果没有找到 [network]，将其添加到文件顶部
        echo "[network]
no_tcp = false
use_udp = true
# PROXY Protocol 配置（默认关闭，可通过菜单配置）
send_proxy = false
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true
" | cat - /root/realm/config.toml > temp && mv temp /root/realm/config.toml
        echo "✅ 增强的[network]配置已添加到 config.toml 文件。"
    else
        echo "✅ [network]配置已存在。"
    fi
}

# 配置PROXY Protocol
configure_proxy_protocol() {
    clear
    echo "—————————————————————"
    echo " PROXY Protocol 配置"
    echo "—————————————————————"
    echo ""
    echo "当前配置状态："
    echo -n "PROXY Protocol 状态："
    check_proxy_protocol_status
    echo ""
    echo "—————————————————————"
    echo " 配置选项："
    echo " [1] 启用发送 PROXY Protocol (A机器)"
    echo " [2] 启用接收 PROXY Protocol (B机器)"
    echo " [3] 启用接收+发送 PROXY Protocol (B机器中转)"
    echo " [4] 禁用 PROXY Protocol"
    echo " [5] 查看当前配置"
    echo " [0] 返回主菜单"
    echo "—————————————————————"
    
    read -e -p "请选择配置选项: " proxy_choice
    
    case $proxy_choice in
        1)
            configure_send_proxy
            ;;
        2)
            configure_accept_proxy
            ;;
        3)
            configure_accept_and_send_proxy
            ;;
        4)
            disable_proxy_protocol
            ;;
        5)
            show_proxy_config
            ;;
        0)
            return
            ;;
        *)
            echo "无效选项，请重试。"
            sleep 2
            configure_proxy_protocol
            ;;
    esac
}

# 配置发送PROXY Protocol (A机器)
configure_send_proxy() {
    echo ""
    echo "配置A机器 - 发送PROXY Protocol"
    echo "适用场景：A机器获取用户真实IP并发送给B机器"
    echo ""
    
    # 更新配置文件
    sed -i 's/send_proxy = .*/send_proxy = true/' /root/realm/config.toml
    sed -i 's/accept_proxy = .*/accept_proxy = false/' /root/realm/config.toml
    
    echo "✅ 已配置为发送PROXY Protocol"
    echo "重启服务以应用配置..."
    systemctl restart realm
    echo "✅ 配置完成"
    
    read -e -p "按回车键返回..."
}

# 配置接收PROXY Protocol (B机器)
configure_accept_proxy() {
    echo ""
    echo "配置B机器 - 接收PROXY Protocol"
    echo "适用场景：B机器接收A机器发送的PROXY Protocol"
    echo ""
    
    # 更新配置文件
    sed -i 's/send_proxy = .*/send_proxy = false/' /root/realm/config.toml
    sed -i 's/accept_proxy = .*/accept_proxy = true/' /root/realm/config.toml
    
    echo "✅ 已配置为接收PROXY Protocol"
    echo "重启服务以应用配置..."
    systemctl restart realm
    echo "✅ 配置完成"
    
    read -e -p "按回车键返回..."
}

# 配置接收+发送PROXY Protocol (B机器中转)
configure_accept_and_send_proxy() {
    echo ""
    echo "配置B机器 - 接收并转发PROXY Protocol"
    echo "适用场景：B机器接收A机器的PROXY Protocol并转发给XrayR"
    echo ""
    
    # 更新配置文件
    sed -i 's/send_proxy = .*/send_proxy = true/' /root/realm/config.toml
    sed -i 's/accept_proxy = .*/accept_proxy = true/' /root/realm/config.toml
    
    echo "✅ 已配置为接收并转发PROXY Protocol"
    echo "重启服务以应用配置..."
    systemctl restart realm
    echo "✅ 配置完成"
    
    read -e -p "按回车键返回..."
}

# 禁用PROXY Protocol
disable_proxy_protocol() {
    echo ""
    echo "禁用PROXY Protocol"
    
    # 更新配置文件
    sed -i 's/send_proxy = .*/send_proxy = false/' /root/realm/config.toml
    sed -i 's/accept_proxy = .*/accept_proxy = false/' /root/realm/config.toml
    
    echo "✅ 已禁用PROXY Protocol"
    echo "重启服务以应用配置..."
    systemctl restart realm
    echo "✅ 配置完成"
    
    read -e -p "按回车键返回..."
}

# 查看PROXY Protocol配置
show_proxy_config() {
    clear
    echo "—————————————————————"
    echo " PROXY Protocol 详细配置"
    echo "—————————————————————"
    
    if [ -f "/root/realm/config.toml" ]; then
        echo "当前配置文件内容："
        echo ""
        grep -A 10 "\\[network\\]" /root/realm/config.toml
        echo ""
        echo "—————————————————————"
        echo "配置说明："
        echo "send_proxy = true     # 发送PROXY Protocol给下游"
        echo "accept_proxy = true   # 接收上游的PROXY Protocol"
        echo "send_proxy_version = 2 # PROXY Protocol版本"
        echo ""
        echo "典型配置场景："
        echo "A机器(获取真实IP): send_proxy=true, accept_proxy=false"
        echo "B机器(中转): send_proxy=true, accept_proxy=true"
        echo "XrayR: 在面板配置中启用PROXY Protocol接收"
    else
        echo "配置文件不存在，请先安装Realm。"
    fi
    
    read -e -p "按回车键返回..."
}

# 查看PROXY Protocol状态
show_proxy_status() {
    clear
    echo "—————————————————————"
    echo " PROXY Protocol 状态检查"
    echo "—————————————————————"
    
    echo -n "当前状态："
    check_proxy_protocol_status
    echo ""
    
    if [ -f "/root/realm/config.toml" ]; then
        local send_proxy=$(grep "send_proxy" /root/realm/config.toml | head -1)
        local accept_proxy=$(grep "accept_proxy" /root/realm/config.toml | head -1)
        local proxy_version=$(grep "send_proxy_version" /root/realm/config.toml | head -1)
        
        echo "详细配置："
        echo "  $send_proxy"
        echo "  $accept_proxy"
        echo "  $proxy_version"
        echo ""
        
        echo "服务状态："
        if systemctl is-active --quiet realm; then
            echo -e "  Realm服务: \\033[0;32m运行中\\033[0m"
        else
            echo -e "  Realm服务: \\033[0;31m未运行\\033[0m"
        fi
        
        echo ""
        echo "架构建议："
        echo "用户 → A机器(send_proxy=true) → B机器(accept+send=true) → XrayR"
        echo "       ↓ 发送真实IP           ↓ 接收并转发真实IP"
    else
        echo "配置文件不存在，请先安装Realm。"
    fi
    
    read -e -p "按回车键返回..."
}

# 卸载realm
uninstall_realm() {
    systemctl stop realm
    systemctl disable realm
    rm -rf /etc/systemd/system/realm.service
    systemctl daemon-reload
    rm -rf /root/realm
    echo "Realm已被卸载。"
    # 更新realm状态变量
    realm_status="未安装"
    realm_status_color="\\033[0;31m" # 红色
}

# 启动服务
start_service() {
    sudo systemctl unmask realm.service
    sudo systemctl daemon-reload
    sudo systemctl restart realm.service
    sudo systemctl enable realm.service

    # 检查服务是否成功启动
    if systemctl is-active --quiet realm; then
        echo -e "\\033[0;32mRealm服务已成功启动并设置为开机自启。\\033[0m"
    else
        echo -e "\\033[0;31mRealm服务启动失败！\\033[0m"
    fi
}

# 停止服务
stop_service() {
    systemctl stop realm

    # 检查服务是否成功停止
    if ! systemctl is-active --quiet realm; then
        echo -e "\\033[0;32mRealm服务已成功停止。\\033[0m"
    else
        echo -e "\\033[0;31mRealm服务停止失败！\\033[0m"
    fi
}

# 重启服务
restart_service() {
    sudo systemctl stop realm
    sudo systemctl unmask realm.service
    sudo systemctl daemon-reload
    sudo systemctl restart realm.service
    sudo systemctl enable realm.service

    # 检查服务是否成功重启
    if systemctl is-active --quiet realm; then
        echo -e "\\033[0;32mRealm服务已成功重启。\\033[0m"
    else
        echo -e "\\033[0;31mRealm服务重启失败！\\033[0m"
    fi
}

# 添加转发规则（简化版，保持原有功能）
add_forward() {
    clear
    echo -e " 添加 Realm 转发规则 "
    echo -e "---------------------------------------------------------------------"

    read -e -p "请输入本地监听端口: " local_port
    if [ -z "$local_port" ]; then
        echo "未输入端口，返回主菜单。"
        return
    fi

    read -e -p "请输入需要转发的IP: " ip
    if [ -z "$ip" ]; then
        echo "未输入IP，返回主菜单。"
        return
    fi

    read -e -p "请输入需要转发端口: " port
    if [ -z "$port" ]; then
        echo "未输入转发端口，返回主菜单。"
        return
    fi

    read -e -p "请输入备注(可为空): " remark

    # 处理IPv6地址的特殊格式
    if [[ "$ip" == \\[*\\]* ]]; then
        remote_format="$ip:$port"
    elif [[ "$ip" == *:*:* ]]; then
        remote_format="[$ip]:$port"
    else
        remote_format="$ip:$port"
    fi

    # 追加到config.toml文件
    echo "[[endpoints]]
# 备注: $remark
listen = \"[::]:$local_port\"
remote = \"$remote_format\"" >> /root/realm/config.toml

    echo "✅ 转发规则已添加"
    sudo systemctl restart realm.service
    echo "✅ Realm服务已重新启动"
}

# 查看转发规则
show_all_conf() {
    clear
    echo -e " 当前 Realm 转发规则 "
    echo -e "---------------------------------------------------------------------"

    local IFS=$'\\n'
    local lines=($(grep -n 'listen =' /root/realm/config.toml 2>/dev/null || echo ""))

    if [ ${#lines[@]} -eq 0 ] || [ -z "$lines" ]; then
        echo -e "没有发现任何转发规则。"
        return
    fi

    local index=1
    for line in "${lines[@]}"; do
        local line_number=$(echo $line | cut -d ':' -f 1)
        local listen_info=$(sed -n "${line_number}p" /root/realm/config.toml | cut -d '"' -f 2)
        local remote_info=$(sed -n "$((line_number + 1))p" /root/realm/config.toml | cut -d '"' -f 2)
        local remark=$(sed -n "$((line_number-1))p" /root/realm/config.toml | grep "^# 备注:" | cut -d ':' -f 2- | sed 's/^ //')

        printf " %-3s | %-12s | %-45s | %-20s\\n" "$index" "$listen_info" "$remote_info" "$remark"
        echo -e "---------------------------------------------------------------------"
        let index+=1
    done
}

# 修改转发规则（简化版）
modify_forward() {
    echo "修改功能请使用原版EZRealm脚本，或手动编辑 /root/realm/config.toml"
    read -e -p "按回车键返回..."
}

# 删除转发规则（简化版）
delete_forward() {
    echo "删除功能请使用原版EZRealm脚本，或手动编辑 /root/realm/config.toml"
    read -e -p "按回车键返回..."
}

# 定时任务
cron_restart() {
    clear
    echo -e "---------------------------------------------------------------------"
    echo -e " Realm定时重启任务 "
    echo -e "---------------------------------------------------------------------"
    echo -e "[1] 配置Realm定时重启任务"
    echo -e "[2] 删除Realm定时重启任务"
    echo -e "---------------------------------------------------------------------"
    read -e -p "请选择: " numcron

    if [ "$numcron" == "1" ]; then
        read -e -p "每？小时重启: " cronhr
        echo "0 */$cronhr * * * root /usr/bin/systemctl restart realm" >>/etc/crontab
        echo -e "定时重启设置成功！"
    elif [ "$numcron" == "2" ]; then
        sed -i "/realm/d" /etc/crontab
        echo -e "定时重启任务删除完成！"
    fi
}

# 导出规则（简化版）
export_rules() {
    echo "导出功能请使用原版EZRealm脚本"
    read -e -p "按回车键返回..."
}

# 导入规则（简化版）
import_rules() {
    echo "导入功能请使用原版EZRealm脚本"
    read -e -p "按回车键返回..."
}

# 主循环（更新选项）
while true; do
    show_menu
    read -e -p "请选择一个选项[0-14]: " choice
    
    # 去掉输入中的空格
    choice=$(echo $choice | tr -d '[:space:]')
    
    # 检查输入是否为数字，并在有效范围内
    if ! [[ "$choice" =~ ^([0-9]|1[0-4])$ ]]; then
        echo "无效选项: $choice"
        continue
    fi
    
    case $choice in
        1) deploy_realm ;;
        2) add_forward ;;  # 保持原有功能
        3) show_all_conf ;;
        4) modify_forward ;;
        5) delete_forward ;;
        6) start_service ;;
        7) stop_service ;;
        8) restart_service ;;
        9) configure_proxy_protocol ;;  # 新增
        10) show_proxy_status ;;        # 新增
        11) uninstall_realm ;;
        12) cron_restart ;;
        13) export_rules ;;
        14) import_rules ;;
        0) 
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项: $choice"
            ;;
    esac
    
    # 如果key变量有值，说明刚从某个操作完成界面返回，无需再次等待按键
    if [ -n "$key" ]; then
        key="" # 清空key变量
        continue
    fi
    
    read -e -p "按任意键返回主菜单..." key
done
