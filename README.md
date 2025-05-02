# HTTPS网络启动服务器配置脚本

## 简介
该脚本用于快速搭建支持 **HTTPS网络启动（UEFI HTTP/HTTPS Boot）** 的服务器环境，允许客户端通过HTTPS协议直接下载引导文件进行系统安装或启动。支持常见Linux发行版（如Ubuntu、CentOS等）的ISO镜像，并自动配置Apache/Nginx、SSL证书和GRUB启动菜单。

---

## 系统要求
1. **服务器环境**：
   - Linux系统（Debian/Ubuntu/RHEL/CentOS/Fedora）
   - 根权限（需以 `root` 或 `sudo` 运行脚本）
2. **网络环境**：
   - 可访问互联网（用于安装依赖）
   - 确保防火墙开放 **443（HTTPS）** 端口
3. **客户端要求**：
   - 支持 **UEFI HTTP Boot** 的固件（需手动配置URL）

---

## 快速开始

### 1. 下载脚本
```bash
wget https://raw.githubusercontent.com/your-repo/your-script.sh
chmod +x your-script.sh
```

### 2. 运行脚本（示例）
```bash
sudo ./your-script.sh \
    --iso /path/to/ubuntu-22.04.iso \
    --cert /etc/letsencrypt/live/boot.local/fullchain.pem \
    --key /etc/letsencrypt/live/boot.local/privkey.pem
```

---

## 参数说明

| 参数              | 说明                                                                 | 必需？ |
|-------------------|----------------------------------------------------------------------|--------|
| `--iso`           | Linux安装ISO镜像路径（必需）                                         | 是     |
| `--interface`     | 网络接口（如 `eth0` 或 `ens33`）                                     | 否     |
| `--ip`            | 服务器IP地址（如 `192.168.1.10`）                                   | 否     |
| `--domain`        | 服务器域名（如 `boot.local`）                                       | 否     |
| `--cert`          | SSL证书路径（如 `/etc/ssl/cert.pem`）                               | 否     |
| `--key`           | SSL私钥路径（如 `/etc/ssl/private.key`）                            | 否     |
| `--help`          | 显示帮助信息                                                       | 否     |

---

## 配置详解

### 1. ISO镜像支持
- **Ubuntu/CentOS/Debian** 等常见发行版的ISO均支持。
- 脚本会自动从ISO中提取内核（`vmlinuz`）、初始化镜像（`initrd.img`）和安装文件。

### 2. SSL证书
- **自签名证书**：若未提供证书，脚本会自动生成（有效期1年）。
- **自定义证书**：可通过 `--cert` 和 `--key` 参数指定已有的证书（如Let's Encrypt证书）。

### 3. 网络配置
- 默认配置静态IP `192.168.1.1`，可通过 `--ip` 修改。
- 确保网络接口（如 `eth0`）可访问内网。

---

## 验证配置

### 1. 检查服务状态
```bash
# Apache（Debian/Ubuntu）
systemctl status apache2

# Nginx（RHEL/CentOS）
systemctl status httpd
```

### 2. 访问HTTPS目录
在浏览器中访问以下URL验证文件是否可下载：
```
https://<服务器IP>/netboot/grub/grub.cfg
https://<服务器IP>/netboot/vmlinuz
```

### 3. 客户端测试
1. 在UEFI固件中启用 **HTTP Boot**。
2. 输入引导URL：
   ```
   https://<服务器IP>/netboot/grub/grub.cfg
   ```
3. 选择菜单项启动安装流程。

---

## 注意事项
1. **证书信任问题**：
   - 若使用自签名证书，客户端需手动信任证书（具体步骤因固件而异）。
2. **防火墙设置**：
   - 确保开放 **443端口**：
     ```bash
     firewall-cmd --add-port=443/tcp --permanent
     firewall-cmd --reload
     ```
3. **ISO镜像要求**：
   - 确保ISO路径正确且可读。
   - 部分ISO可能需要调整内核路径（如CentOS的 `images/pxeboot` 和Ubuntu的 `casper`）。

---

## 常见问题

### Q1：客户端无法连接？
- 检查防火墙是否开放 **443端口**。
- 确认服务器IP和域名配置正确。
- 使用 `curl -k https://<IP>/netboot/grub/grub.cfg` 测试访问。

### Q2：证书错误？
- 使用自签名证书时，客户端需手动信任证书。
- 使用Let's Encrypt证书时，确保域名已解析到服务器IP。

### Q3：安装时提示“找不到镜像”？
- 检查ISO文件是否完整。
- 确认脚本运行后 `/var/www/html/netboot/os` 目录下有安装文件。

---



## 贡献指南
欢迎提交Issue或Pull Request修复问题或改进脚本！
