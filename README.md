# Realm 网络转发管理工具

🌟 **功能强大的 Realm 网络转发一键管理脚本**

一个基于 [zhboner/realm](https://github.com/zhboner/realm) 的完整管理解决方案，提供交互式菜单界面，支持 PROXY Protocol、多种传输协议、IPv4/IPv6 双栈配置等高级功能。

## ✨ 主要特性

### 🚀 核心功能
- **一键安装/卸载** - 自动检测系统架构，支持 x86_64 和 aarch64
- **交互式菜单** - 友好的中文界面，操作简单直观
- **GitHub 加速** - 内置多个加速代理，解决国内下载问题
- **智能配置** - 自动生成和验证配置文件
- **服务管理** - 完整的 systemd 服务管理功能

### 🔐 PROXY Protocol 支持
- **A机器配置** - 发送 PROXY Protocol 到 B 机器
- **B机器配置** - 接收并转发 PROXY Protocol 到 XrayR
- **真实IP透传** - 确保 XrayR 获取用户真实 IP 地址
- **连接数限制** - 基于真实 IP 的连接数控制

### 🌐 多种传输协议
- **TCP** - 标准 TCP 直连转发
- **WebSocket** - 穿透 HTTP 代理和防火墙
- **TLS** - 传输层加密保护
- **WSS** - WebSocket over TLS，双重保护
- **随机伪装** - 内置 80+ 域名池和路径池

### 🌍 IPv4/IPv6 双栈支持
- **标准双栈** - IPv4+IPv6 同时监听
- **纯 IPv6** - IPv6 监听和转发
- **反向双栈** - IPv6 监听，IPv4 转发
- **智能检测** - 自动检测本机 IP 地址

### 📊 监控和管理
- **实时日志** - 查看服务运行状态
- **连接统计** - 监控活跃连接数
- **网络测试** - 测试转发目标连通性
- **配置备份** - 自动备份和恢复功能

## 🚀 快速开始

### 安装脚本

```bash
# 下载并运行脚本
wget -O realm-manager.sh https://raw.githubusercontent.com/q42602736/realm/main/install.sh
chmod +x realm-manager.sh
./realm-manager.sh
```

### 基本使用流程

1. **选择 GitHub 加速** - 首次使用会提示选择下载加速方式
2. **安装 Realm** - 选择菜单选项 `1` 安装 Realm
3. **配置 PROXY Protocol** - 选择菜单选项 `12` 配置协议
4. **添加转发规则** - 选择菜单选项 `4` 添加转发规则
5. **启动服务** - 选择菜单选项 `8` 启动服务

## 📋 菜单功能详解

### 📦 基础管理
- `1. 安装 Realm` - 自动下载并安装 Realm 二进制文件
- `2. 卸载 Realm` - 完全卸载 Realm 及配置文件
- `3. GitHub代理` - 更换 GitHub 下载加速代理

### 🔧 规则管理
- `4. 添加规则` - 添加新的转发规则
- `5. 查看规则` - 显示所有转发规则
- `6. 删除规则` - 删除指定转发规则
- `7. 修复配置` - 修复损坏的配置文件

### ⚙️ 服务管理
- `8. 启动服务` - 启动 Realm 服务
- `9. 停止服务` - 停止 Realm 服务
- `10. 重启服务` - 重启 Realm 服务
- `11. 服务状态` - 查看服务运行状态

### 🔐 PROXY 协议
- `12. 配置PROXY` - 配置 PROXY Protocol 参数
- `13. PROXY状态` - 查看当前 PROXY 配置状态

### 🌐 传输层配置
- `14. WebSocket` - 配置 WebSocket 传输
- `15. TLS加密` - 配置 TLS 加密传输
- `16. WSS配置` - 配置 WebSocket over TLS
- `17. WS隧道配置` - 高级 WebSocket 隧道配置
- `18. 传输层状态` - 查看传输层配置状态

### 📊 监控工具
- `19. 实时日志` - 查看实时运行日志
- `20. 错误日志` - 查看错误和警告日志
- `21. 连接统计` - 查看连接数和统计信息
- `22. 网络测试` - 测试网络连通性

### 🛠️ 系统工具
- `23. 备份配置` - 备份当前配置文件
- `24. 恢复配置` - 从备份恢复配置
- `25. 更新脚本` - 更新管理脚本到最新版本

## 🔧 配置示例

### PROXY Protocol 配置

#### A机器配置（国内服务器）
```toml
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
listen = "0.0.0.0:29731"
remote = "B机器IP:8080"
```

#### B机器配置（海外服务器）
```toml
[network]
no_tcp = false
use_udp = true
send_proxy = true
accept_proxy = true
send_proxy_version = 2
tcp_timeout = 10
tcp_nodelay = true

[[endpoints]]
# 备注: 接收A机器转发
listen = "0.0.0.0:8080"
remote = "127.0.0.1:XrayR端口"
```

### WebSocket 隧道配置

```toml
[[endpoints]]
# 备注: WebSocket隧道
listen = "0.0.0.0:29731"
remote = "目标服务器:8080"
transport = "ws;host=www.microsoft.com;path=/ws"
```

### WSS 加密隧道配置

```toml
[[endpoints]]
# 备注: WSS加密隧道
listen = "0.0.0.0:29731"
remote = "目标服务器:8080"
transport = "ws;tls;host=www.google.com;path=/websocket"
```

## 🌍 IPv6 配置指南

### 纯 IPv6 隧道
- A机器：IPv6 监听，通过 WebSocket 向 B机器 IPv6 转发
- B机器：IPv6 监听 WebSocket，向 XrayR 转发

### 反向双栈隧道
- A机器：IPv6 监听，通过 WebSocket 向 B机器 IPv4 转发
- B机器：IPv4 监听 WebSocket，向 XrayR 转发

## 🔍 故障排除

### 常见问题

1. **下载失败**
   - 尝试更换 GitHub 加速代理
   - 检查网络连接
   - 使用直连模式

2. **服务启动失败**
   - 检查配置文件语法
   - 查看错误日志：`journalctl -u realm -n 50`
   - 验证端口是否被占用

3. **连接不通**
   - 检查防火墙设置
   - 验证目标地址可达性
   - 确认端口配置正确

4. **PROXY Protocol 不生效**
   - 确认 A机器 `send_proxy = true`
   - 确认 B机器 `accept_proxy = true`
   - 检查 XrayR 是否启用 PROXY Protocol

### 日志查看命令

```bash
# 查看实时日志
journalctl -u realm -f

# 查看错误日志
journalctl -u realm -p err --since "24 hours ago"

# 查看最近日志
journalctl -u realm -n 50
```

## 🔄 更新说明

脚本支持自动更新功能：
- 使用菜单选项 `25` 检查并更新到最新版本
- 支持 GitHub 加速下载
- 自动备份当前版本
- 更新后自动重启脚本

## 📞 技术支持

- **项目地址**: https://github.com/q42602736/realm
- **原项目**: https://github.com/zhboner/realm
- **问题反馈**: 通过 GitHub Issues 提交

## 🌐 高级功能详解

### WS隧道配置（选项17）

脚本提供了6种不同的WebSocket隧道配置模式：

1. **标准双栈隧道** - IPv4+IPv6同时监听和转发
2. **双栈客户端隧道** - IPv4+IPv6监听，IPv4转发
3. **双栈服务端隧道** - IPv4监听，IPv4+IPv6转发
4. **纯IPv6隧道** - IPv6监听和转发
5. **反向双栈隧道** - IPv6监听，IPv4转发
6. **单独配置** - 分别配置客户端或服务端

### 随机伪装功能

脚本内置了丰富的伪装资源池：

#### 伪装域名池（80+个）
- 科技公司：Microsoft、Google、Apple、Amazon等
- 社交媒体：Facebook、Twitter、Instagram等
- 视频平台：YouTube、Netflix、Twitch等
- 开发平台：GitHub、GitLab、Docker等
- 云服务：CloudFlare、AWS、Azure等

#### WebSocket路径池（30+个）
- 常见路径：/ws、/websocket、/api、/connect
- 业务路径：/stream、/chat、/live、/gateway
- 系统路径：/health、/status、/monitor等

### 智能网络检测

脚本具备智能网络环境检测功能：

- **端口占用检测** - 自动检查端口是否被占用
- **IPv6地址检测** - 自动检测本机IPv6地址
- **网络工具适配** - 自动安装和使用netstat或ss命令
- **连通性测试** - 测试转发目标的可达性

## 🔧 详细配置说明

### PROXY Protocol 工作原理

PROXY Protocol 是一种网络协议，用于在代理服务器和后端服务器之间传递客户端的真实IP地址。

#### 配置场景
```
用户 → A机器(国内) → B机器(海外) → XrayR
```

#### 配置要点
- **A机器**: `send_proxy = true, accept_proxy = false`
- **B机器**: `send_proxy = true, accept_proxy = true`
- **XrayR**: 启用PROXY Protocol接收

### 传输协议选择指南

| 协议 | 特点 | 适用场景 |
|------|------|----------|
| TCP | 直连，性能最佳 | 网络环境良好，无防火墙限制 |
| WebSocket | 穿透HTTP代理 | 有HTTP代理或防火墙限制 |
| TLS | 加密传输 | 需要传输层加密保护 |
| WSS | WebSocket+TLS | 既需要穿透又需要加密 |

### IPv6配置最佳实践

#### 纯IPv6环境
```toml
[network]
ipv6_only = true
send_proxy = true
accept_proxy = true

[[endpoints]]
listen = "[::]:29731"
remote = "[2001:db8::1]:8080"
transport = "ws;host=www.example.com;path=/ws"
```

#### 双栈环境
```toml
[network]
ipv6_only = false
send_proxy = true
accept_proxy = true

[[endpoints]]
listen = "[::]:29731"  # 同时监听IPv4和IPv6
remote = "example.com:8080"
```

## �️ 运维管理

### 服务管理命令

```bash
# 查看服务状态
systemctl status realm

# 启动服务
systemctl start realm

# 停止服务
systemctl stop realm

# 重启服务
systemctl restart realm

# 开机自启
systemctl enable realm

# 禁用自启
systemctl disable realm
```

### 配置文件位置

- **主配置文件**: `/root/realm/config.toml`
- **服务文件**: `/etc/systemd/system/realm.service`
- **程序文件**: `/root/realm/realm`
- **备份目录**: `/root/realm_backups/`

### 防火墙配置

#### UFW防火墙
```bash
# 允许端口
ufw allow 29731

# 查看规则
ufw status
```

#### iptables防火墙
```bash
# IPv4规则
iptables -A INPUT -p tcp --dport 29731 -j ACCEPT

# IPv6规则
ip6tables -A INPUT -p tcp --dport 29731 -j ACCEPT
```

## 📊 性能优化

### 系统参数优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 65536 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 134217728" >> /etc/sysctl.conf

# 应用配置
sysctl -p
```

### 监控脚本

创建监控脚本 `/root/realm_monitor.sh`：

```bash
#!/bin/bash
# Realm服务监控脚本

check_service() {
    if ! systemctl is-active --quiet realm; then
        echo "$(date): Realm服务已停止，正在重启..." >> /var/log/realm_monitor.log
        systemctl restart realm
        sleep 5
        if systemctl is-active --quiet realm; then
            echo "$(date): Realm服务重启成功" >> /var/log/realm_monitor.log
        else
            echo "$(date): Realm服务重启失败" >> /var/log/realm_monitor.log
        fi
    fi
}

check_service
```

添加到crontab：
```bash
# 每分钟检查一次服务状态
* * * * * /root/realm_monitor.sh
```

## �📄 许可证

本项目基于原 Realm 项目的许可证发布。

---

**⚠️ 重要提醒**
- 请确保在合法合规的前提下使用本工具
- 建议在测试环境中验证配置后再部署到生产环境
- 定期备份配置文件以防数据丢失
- 监控服务运行状态，及时处理异常情况
