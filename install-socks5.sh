#!/bin/bash

echo "=== SOCKS5 Dante Installer (Multi-Port + Auto Port Finder) ==="

# Cek root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan sebagai root!" >&2
    exit 1
fi

# Input user
read -p "Masukkan domain kamu (contoh: socksjep.ct.ws): " DOMAIN
read -p "Masukkan username SOCKS5: " SOCKS_USER
read -sp "Masukkan password SOCKS5: " SOCKS_PASS
echo ""

# Validasi password
if [ -z "$SOCKS_PASS" ] || [ ${#SOCKS_PASS} -lt 4 ]; then
    echo "Password harus minimal 4 karakter!" >&2
    exit 1
fi

# Install dante-server
apt update
apt install -y dante-server curl

# Fungsi cek port
find_available_port() {
    local start_port=1080
    local end_port=2000
    for port in $(seq $start_port $end_port); do
        if ! ss -tuln | grep -q ":${port} "; then
            echo $port
            return 0
        fi
    done
    echo "❌ Tidak ada port yang tersedia di range $start_port-$end_port" >&2
    exit 1
}

# Cari port yang tersedia
SOCKS_PORT=$(find_available_port)
if [ -z "$SOCKS_PORT" ]; then
    exit 1
fi

# Buat user tanpa akses shell
if ! id "$SOCKS_USER" &>/dev/null; then
    useradd -M -s /usr/sbin/nologin "$SOCKS_USER"
    echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd
else
    echo "⚠️ User $SOCKS_USER sudah ada. Password diupdate."
    echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd
fi

# Ambil interface utama
IFACE=$(ip -o -4 route show default | awk '{print $5}')
if [ -z "$IFACE" ]; then
    echo "❌ Tidak bisa deteksi interface jaringan!" >&2
    exit 1
fi

# Buat config danted
cat > /etc/danted.conf <<EOF
logoutput: syslog
internal: $IFACE port = $SOCKS_PORT
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
    log: connect disconnect error
}
EOF

# Restart dan cek service
systemctl restart danted
if ! systemctl is-active --quiet danted; then
    echo "❌ Gagal menjalankan danted. Cek log: journalctl -u danted" >&2
    exit 1
fi
systemctl enable danted

# Buka firewall (UFW)
if command -v ufw &> /dev/null; then
    ufw allow $SOCKS_PORT/tcp
    ufw allow $SOCKS_PORT/udp
fi

# Validasi domain
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

# Hasil akhir
echo ""
echo "=== SOCKS5 Berhasil Dipasang! ==="
echo "Domain  : $DOMAIN"
echo "Port    : $SOCKS_PORT (otomatis dipilih)"
echo "Username: $SOCKS_USER"
echo "Password: $SOCKS_PASS"
echo "Format  : $DOMAIN:$SOCKS_PORT:$SOCKS_USER:$SOCKS_PASS"
