#!/bin/bash
# Realm 配置文件修复工具

echo "========================================"
echo "Realm 配置文件修复工具"
echo "========================================"

CONFIG_FILE="/root/realm/config.toml"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 备份原配置文件
backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$backup_file"
echo "✅ 原配置已备份到: $backup_file"

# 显示当前配置
echo ""
echo "当前配置文件内容："
echo "—————————————————————"
cat "$CONFIG_FILE"
echo "—————————————————————"

# 检查配置文件是否损坏
echo ""
echo "检查配置文件格式..."

# 尝试启动realm来验证配置
if systemctl restart realm 2>/dev/null; then
    echo "✅ 配置文件格式正确，服务启动成功"
    systemctl status realm --no-pager -l
    exit 0
else
    echo "❌ 配置文件格式错误，开始修复..."
fi

# 解析现有的规则
declare -a listen_ports=()
declare -a remote_addrs=()
declare -a remarks=()

echo ""
echo "解析现有规则..."

while IFS= read -r line; do
    if [[ "$line" =~ ^#.*备注: ]]; then
        current_remark=$(echo "$line" | sed 's/^#.*备注: *//')
    elif [[ "$line" =~ ^listen.*= ]]; then
        listen_port=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        if [ -n "$listen_port" ]; then
            listen_ports+=("$listen_port")
            remarks+=("${current_remark:-}")
            current_remark=""
        fi
    elif [[ "$line" =~ ^remote.*= ]]; then
        remote_addr=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"')
        if [ -n "$remote_addr" ]; then
            remote_addrs+=("$remote_addr")
        fi
    fi
done < "$CONFIG_FILE"

echo "找到 ${#listen_ports[@]} 个规则"

# 如果没有找到规则，提供默认配置选项
if [ ${#listen_ports[@]} -eq 0 ]; then
    echo ""
    echo "没有找到有效规则，请选择配置类型："
    echo " [1] A机器配置 (发送PROXY Protocol)"
    echo " [2] B机器配置 (接收+发送PROXY Protocol)"
    echo " [3] 手动输入配置"
    echo " [0] 退出"
    
    read -e -p "请选择: " config_type
    
    case $config_type in
        1)
            # A机器配置
            read -e -p "请输入监听端口 (默认27433): " listen_port
            listen_port=${listen_port:-27433}
            read -e -p "请输入B机器IP (默认35.220.213.151): " b_ip
            b_ip=${b_ip:-35.220.213.151}
            read -e -p "请输入B机器端口 (默认29731): " b_port
            b_port=${b_port:-29731}
            
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = false
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

[[endpoints]]
# 备注: 转发到B机器
listen = "0.0.0.0:$listen_port"
remote = "$b_ip:$b_port"
EOF
            ;;
        2)
            # B机器配置
            read -e -p "请输入监听端口 (默认29731): " listen_port
            listen_port=${listen_port:-29731}
            read -e -p "请输入XrayR地址 (默认afeihk6.54141528.xyz): " xrayr_host
            xrayr_host=${xrayr_host:-afeihk6.54141528.xyz}
            read -e -p "请输入XrayR端口 (默认13444): " xrayr_port
            xrayr_port=${xrayr_port:-13444}
            
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
# 备注: 接收A机器，转发给XrayR
listen = "0.0.0.0:$listen_port"
remote = "$xrayr_host:$xrayr_port"
EOF
            ;;
        3)
            # 手动输入
            read -e -p "请输入监听端口: " listen_port
            read -e -p "请输入转发地址: " remote_addr
            read -e -p "发送PROXY Protocol? (y/N): " send_proxy
            read -e -p "接收PROXY Protocol? (y/N): " accept_proxy
            
            send_proxy_val="false"
            accept_proxy_val="false"
            [[ "$send_proxy" =~ ^[Yy]$ ]] && send_proxy_val="true"
            [[ "$accept_proxy" =~ ^[Yy]$ ]] && accept_proxy_val="true"
            
            cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = $send_proxy_val
accept_proxy = $accept_proxy_val
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

[[endpoints]]
# 备注: 手动配置
listen = "0.0.0.0:$listen_port"
remote = "$remote_addr"
EOF
            ;;
        0)
            echo "已退出"
            exit 0
            ;;
        *)
            echo "无效选择"
            exit 1
            ;;
    esac
else
    # 重新生成配置文件
    echo ""
    echo "重新生成配置文件..."
    
    # 询问PROXY Protocol配置
    echo "请确认PROXY Protocol配置："
    read -e -p "发送PROXY Protocol? (y/N): " send_proxy
    read -e -p "接收PROXY Protocol? (y/N): " accept_proxy
    
    send_proxy_val="false"
    accept_proxy_val="false"
    [[ "$send_proxy" =~ ^[Yy]$ ]] && send_proxy_val="true"
    [[ "$accept_proxy" =~ ^[Yy]$ ]] && accept_proxy_val="true"
    
    # 生成新配置文件
    cat > "$CONFIG_FILE" << EOF
[network]
no_tcp = false
use_udp = true
send_proxy = $send_proxy_val
accept_proxy = $accept_proxy_val
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

EOF
    
    # 添加所有规则
    for ((i=0; i<${#listen_ports[@]}; i++)); do
        cat >> "$CONFIG_FILE" << EOF
[[endpoints]]
# 备注: ${remarks[$i]}
listen = "${listen_ports[$i]}"
remote = "${remote_addrs[$i]}"

EOF
    done
fi

echo ""
echo "✅ 配置文件已修复"
echo ""
echo "新配置文件内容："
echo "—————————————————————"
cat "$CONFIG_FILE"
echo "—————————————————————"

# 测试新配置
echo ""
echo "测试新配置..."
if systemctl restart realm; then
    echo "✅ 配置修复成功，服务启动正常"
    systemctl status realm --no-pager -l
else
    echo "❌ 配置仍有问题，恢复备份"
    cp "$backup_file" "$CONFIG_FILE"
    systemctl restart realm
fi

echo ""
echo "========================================"
echo "修复完成"
echo "========================================"
