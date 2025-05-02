#!/bin/bash

# HTTPS网络启动服务器配置脚本

# 默认配置
DEFAULT_INTERFACE="eth0"          # 默认网络接口
DEFAULT_IP="192.168.1.1"         # 默认IP地址
DEFAULT_DOMAIN="boot.local"      # 默认域名
HTTPS_PORT="443"                 # HTTPS端口
HTTP_ROOT="/var/www/html"         # HTTP根目录
BOOT_DIR="$HTTP_ROOT/netboot"     # 引导文件目录
GRUB_DIR="$BOOT_DIR/grub"        # GRUB目录
SSL_DIR="/etc/ssl/private"        # SSL证书目录

# 帮助信息
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --interface <interface>  网络接口名称 (默认: $DEFAULT_INTERFACE)"
    echo "  --ip <ip>               服务器IP地址 (默认: $DEFAULT_IP)"
    echo "  --domain <domain>       服务器域名 (默认: $DEFAULT_DOMAIN)"
    echo "  --iso <path>            Linux安装ISO路径 (必需)"
    echo "  --cert <path>           SSL证书路径 (可选)"
    echo "  --key <path>            SSL私钥路径 (可选)"
    echo "  --help                  显示此帮助信息"
}

# 参数解析
INTERFACE=$DEFAULT_INTERFACE
SERVER_IP=$DEFAULT_IP
DOMAIN=$DEFAULT_DOMAIN
ISO_PATH=""
CERT_PATH=""
KEY_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --interface)
            INTERFACE="$2"
            shift 2
            ;;
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --cert)
            CERT_PATH="$2"
            shift 2
            ;;
        --key)
            KEY_PATH="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "错误：未知选项 $1"
            show_usage
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$ISO_PATH" ]; then
    echo "错误：必须指定ISO镜像路径 (--iso)"
    show_usage
    exit 1
fi

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本必须以root权限运行"
    exit 1
fi

# 检查ISO文件
check_iso() {
    if [ ! -f "$ISO_PATH" ]; then
        echo "错误：ISO文件不存在：$ISO_PATH"
        exit 1
    fi
}

# 安装必需的软件包
install_packages() {
    echo "正在安装必需的软件包..."
    
    # 检测包管理器
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu系统
        apt-get update
        apt-get install -y apache2 grub-efi-amd64-bin grub-common ssl-cert
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS/Fedora系统
        dnf install -y httpd grub2-efi-x64 grub2-common mod_ssl openssl
    elif command -v yum &> /dev/null; then
        # 旧版RHEL/CentOS系统
        yum install -y httpd grub2-efi-x64 grub2-common mod_ssl openssl
    else
        echo "错误：不支持的Linux发行版"
        exit 1
    fi
}

# 生成自签名证书（如果未提供证书）
generate_certificate() {
    if [ -z "$CERT_PATH" ] || [ -z "$KEY_PATH" ]; then
        echo "未提供证书和私钥，正在生成自签名证书..."
        
        # 创建SSL目录
        mkdir -p $SSL_DIR
        
        # 生成私钥和证书
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/netboot.key" \
            -out "$SSL_DIR/netboot.crt" \
            -subj "/CN=$DOMAIN"
        
        CERT_PATH="$SSL_DIR/netboot.crt"
        KEY_PATH="$SSL_DIR/netboot.key"
    fi
}

# 配置HTTPS服务器
configure_https() {
    echo "正在配置HTTPS服务器..."
    
    # 创建目录结构
    mkdir -p $BOOT_DIR $GRUB_DIR
    
    # 设置目录权限
    chmod -R 755 $BOOT_DIR
    
    # 配置Apache HTTPS
    if [ -d /etc/apache2 ]; then
        # Debian/Ubuntu
        a2enmod ssl
        
        # 创建HTTPS虚拟主机配置
        cat > /etc/apache2/sites-available/netboot-ssl.conf << EOF
<VirtualHost *:${HTTPS_PORT}>
    ServerName $DOMAIN
    DocumentRoot $HTTP_ROOT
    SSLEngine on
    SSLCertificateFile $CERT_PATH
    SSLCertificateKeyFile $KEY_PATH
    
    <Directory $BOOT_DIR>
        Options Indexes FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF
        
        a2ensite netboot-ssl
    elif [ -d /etc/httpd ]; then
        # RHEL/CentOS
        cat > /etc/httpd/conf.d/netboot-ssl.conf << EOF
<VirtualHost *:${HTTPS_PORT}>
    ServerName $DOMAIN
    DocumentRoot $HTTP_ROOT
    SSLEngine on
    SSLCertificateFile $CERT_PATH
    SSLCertificateKeyFile $KEY_PATH
    
    <Directory $BOOT_DIR>
        Options Indexes FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF
    fi
}

# 配置GRUB
configure_grub() {
    echo "正在配置GRUB..."
    
    # 创建GRUB配置目录
    mkdir -p $GRUB_DIR/fonts
    mkdir -p $GRUB_DIR/i386-pc
    
    # 复制GRUB文件
    cp -r /usr/lib/grub/x86_64-efi/* $GRUB_DIR/
    
    # 创建GRUB配置文件
    cat > $GRUB_DIR/grub.cfg << EOF
set default=0
set timeout=5

menuentry "Install Linux (HTTPS Boot)" {
    linux /vmlinuz ip=dhcp inst.repo=https://$DOMAIN/netboot/os
    initrd /initrd.img
}

menuentry "Boot from local drive" {
    set root=(hd0,1)
    chainloader +1
}
EOF
}

# 准备引导文件
prepare_boot_files() {
    echo "正在准备引导文件..."
    
    # 挂载ISO
    local MOUNT_POINT="/mnt/iso"
    mkdir -p $MOUNT_POINT
    mount -o loop "$ISO_PATH" $MOUNT_POINT
    
    # 创建OS目录
    mkdir -p $BOOT_DIR/os
    
    # 复制内核和initrd
    if [ -f $MOUNT_POINT/images/pxeboot/vmlinuz ]; then
        cp $MOUNT_POINT/images/pxeboot/vmlinuz $BOOT_DIR/
        cp $MOUNT_POINT/images/pxeboot/initrd.img $BOOT_DIR/
    elif [ -f $MOUNT_POINT/casper/vmlinuz ]; then
        cp $MOUNT_POINT/casper/vmlinuz $BOOT_DIR/
        cp $MOUNT_POINT/casper/initrd $BOOT_DIR/initrd.img
    else
        echo "错误：无法找到内核和initrd文件"
        umount $MOUNT_POINT
        exit 1
    fi
    
    # 复制安装文件
    cp -r $MOUNT_POINT/* $BOOT_DIR/os/
    
    # 卸载ISO
    umount $MOUNT_POINT
}

# 配置网络接口
configure_network() {
    echo "正在配置网络接口..."
    
    # 获取接口当前配置
    local CURRENT_IP=$(ip addr show $INTERFACE | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    
    if [ "$CURRENT_IP" != "$SERVER_IP" ]; then
        # 配置IP地址
        ip addr add $SERVER_IP/24 dev $INTERFACE
    fi
}

# 启动服务
start_services() {
    echo "正在启动HTTPS服务..."
    
    if command -v systemctl &> /dev/null; then
        systemctl enable --now apache2 || systemctl enable --now httpd
    else
        service apache2 start || service httpd start
    fi
}

# 主程序
echo "=== 开始配置HTTPS网络启动服务器 ==="
echo "网络接口: $INTERFACE"
echo "服务器IP: $SERVER_IP"
echo "域名: $DOMAIN"
echo "ISO镜像: $ISO_PATH"
echo "==========================="

# 执行配置
check_iso
install_packages
generate_certificate
configure_https
configure_grub
prepare_boot_files
configure_network
start_services

echo "=== HTTPS网络启动服务器配置完成 ==="
echo "现在你可以通过HTTPS启动客户端机器进行安装了"
echo "请确保客户端机器支持HTTPS启动并已正确配置"
echo "引导URL: https://$DOMAIN/netboot/grub/grub.cfg"
echo "注意：如果使用自签名证书，客户端需要信任该证书"

exit 0