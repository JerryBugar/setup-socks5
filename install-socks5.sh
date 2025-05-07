#!/bin/bash

echo "=== SOCKS5 Dante Installer (TCP+UDP + Domain Support) ==="

read -p "Masukkan domain kamu (contoh: socksjep.ct.ws): " DOMAIN
read -p "Masukkan username SOCKS5: " SOCKS_USER
read -sp "Masukkan password SOCKS5: " SOCKS_PASS
echo ""

# Install dante-server
apt update
apt install -y dante-server curl

# Buat user tanpa akses shell
useradd -M -s /usr/sbin/nologin $SOCKS_USER
echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd

# Ambil interface utama (biasanya eth0, ens3, dll)
IFACE=$(ip route | grep default | awk '{print $5}')

# Buat config danted
cat > /etc/danted.conf <<EOF
logoutput: syslog
internal: $IFACE port = 1080
external: $IFACE

socksmethod: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect bind udpassociate
    protocol: tcp
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: udpassociate
    protocol: udp
    log: connect disconnect error
}
EOF

# Restart dan enable service
systemctl restart danted
systemctl enable danted

# Buka firewall port TCP/UDP (jika pakai ufw)
if command -v ufw &> /dev/null; then
    ufw allow 1080/tcp
    ufw allow 1080/udp
fi

# Validasi domain resolve ke IP VPS
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)

echo ""
if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
    echo "✅ Domain $DOMAIN sudah mengarah ke IP VPS ($SERVER_IP)"
else
    echo "⚠️ WARNING: Domain $DOMAIN belum mengarah ke IP VPS ($SERVER_IP)"
    echo "➡️  Silakan update A Record domain kamu ke IP VPS ini!"
    echo "   A Record: $DOMAIN ➜ $SERVER_IP"
fi

# Tampilkan info SOCKS5
echo ""
echo "=== SOCKS5 Berhasil Dipasang! ==="
echo "Domain  : $DOMAIN"
echo "Port    : 1080"
echo "Username: $SOCKS_USER"
echo "Password: $SOCKS_PASS"
echo "Format  : $DOMAIN:1080:$SOCKS_USER:$SOCKS_PASS"
