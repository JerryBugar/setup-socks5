#!/bin/bash

echo "=== SOCKS5 Dante Installer (TCP+UDP + Domain Support + Multi-Port) ==="

read -p "Masukkan domain kamu (contoh: socksjep.ct.ws): " DOMAIN
read -p "Masukkan username SOCKS5: " SOCKS_USER
read -sp "Masukkan password SOCKS5: " SOCKS_PASS
echo ""
read -p "Masukkan port (pisahkan dengan koma untuk multi-port, contoh: 1080,1081,1082): " PORTS

# Konversi string port ke array
IFS=',' read -r -a PORT_ARRAY <<< "$PORTS"

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
EOF

# Tambahkan konfigurasi untuk setiap port
for PORT in "${PORT_ARRAY[@]}"; do
  cat >> /etc/danted.conf <<EOF
internal: $IFACE port = $PORT
EOF
done

# Lanjutkan dengan konfigurasi umum
cat >> /etc/danted.conf <<EOF
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
    for PORT in "${PORT_ARRAY[@]}"; do
        ufw allow $PORT/tcp
        ufw allow $PORT/udp
    done
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
echo "Port    : $PORTS"
echo "Username: $SOCKS_USER"
echo "Password: $SOCKS_PASS"

# Tampilkan format untuk setiap port
echo ""
echo "=== Format Koneksi SOCKS5 ==="
for PORT in "${PORT_ARRAY[@]}"; do
    echo "$DOMAIN:$PORT:$SOCKS_USER:$SOCKS_PASS"
done
