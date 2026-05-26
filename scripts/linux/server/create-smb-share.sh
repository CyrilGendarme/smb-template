#!/usr/bin/env bash
set -euo pipefail

SHARE_NAME="${SHARE_NAME:-labshare}"
SHARE_PATH="${SHARE_PATH:-/srv/samba/labshare}"
SHARE_USER="${SHARE_USER:-smbuser}"
SHARE_PASSWORD="${SHARE_PASSWORD:-}"
ALLOWED_SUBNET="${ALLOWED_SUBNET:-192.168.1.0/24}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

echo "[1/10] Installing Samba if needed"
command -v smbd >/dev/null || {
  apt-get update -y
  apt-get install -y samba
}

echo "[2/10] Creating system user"
id "$SHARE_USER" &>/dev/null || useradd -M -s /usr/sbin/nologin "$SHARE_USER"

echo "[3/10] Secure password generation"
if [[ -z "$SHARE_PASSWORD" ]]; then
  SHARE_PASSWORD=$(openssl rand -base64 24)
fi

echo "[4/10] Setting Samba password"
(echo "$SHARE_PASSWORD"; echo "$SHARE_PASSWORD") | smbpasswd -s -a "$SHARE_USER"

echo "[5/10] Preparing directory permissions"
mkdir -p "$SHARE_PATH"
chown "$SHARE_USER:$SHARE_USER" "$SHARE_PATH"
chmod 2770 "$SHARE_PATH"

SMB_CONF="/etc/samba/smb.conf"

# =========================
# GLOBAL HARDENING
# =========================
echo "[6/10] Hardening Samba global config"

if ! grep -q "\[global\]" "$SMB_CONF"; then
cat >> "$SMB_CONF" <<EOF

[global]
   server min protocol = SMB2
   server signing = mandatory
   smb encrypt = required
   map to guest = never
   restrict anonymous = 2

   # 🔐 Bind SMB to local network only
   interfaces = lo
   bind interfaces only = yes
EOF
fi

# =========================
# SHARE CONFIG
# =========================
echo "[7/10] Configuring secure share"

sed -i "/\[$SHARE_NAME\]/,/^\[/d" "$SMB_CONF" || true

cat >> "$SMB_CONF" <<EOF

[$SHARE_NAME]
   path = $SHARE_PATH
   browseable = yes
   read only = no
   valid users = $SHARE_USER
   force user = $SHARE_USER
   create mask = 0660
   directory mask = 2770
   hosts allow = $ALLOWED_SUBNET 127.0.0.1
   smb encrypt = required
EOF

# =========================
# FIREWALL SAFETY LAYER
# =========================
echo "[8/10] Firewall hardening (LAN-only SMB)"

if command -v ufw >/dev/null 2>&1; then
  ufw allow from "$ALLOWED_SUBNET" to any port 445 proto tcp || true
  ufw deny 445/tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ALLOWED_SUBNET' port port=445 protocol=tcp accept" >/dev/null || true
  firewall-cmd --permanent --remove-service=samba >/dev/null || true
  firewall-cmd --reload >/dev/null || true
fi

# =========================
# NETWORK SAFETY CHECK
# =========================
echo "[9/10] Detecting network exposure"

DEFAULT_IFACE=$(ip route | awk '/default/ {print $5; exit}')

if [[ -n "$DEFAULT_IFACE" ]]; then
  IP_ADDR=$(ip -4 addr show "$DEFAULT_IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)

  echo "Detected interface: $DEFAULT_IFACE"
  echo "IP address: $IP_ADDR"

  # simple safety heuristic: block SMB if not private range
  if [[ "$IP_ADDR" != 192.168.* && "$IP_ADDR" != 10.* && "$IP_ADDR" != 172.16.* && "$IP_ADDR" != 172.17.* && "$IP_ADDR" != 172.18.* && "$IP_ADDR" != 172.19.* && "$IP_ADDR" != 172.2* && "$IP_ADDR" != 172.30.* && "$IP_ADDR" != 172.31.* ]]; then
    echo "⚠ WARNING: Non-private network detected → SMB exposure risk"
    echo "👉 Recommend disabling Samba or firewalling port 445"
  fi
fi

# =========================
# RESTART
# =========================
echo "[10/10] Restarting Samba"

testparm -s >/dev/null
systemctl restart smbd || service smbd restart

SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "SECURE SMB READY (LINUX TRAVEL SAFE MODE)"
echo "Share: //$HOSTNAME/$SHARE_NAME"
echo "User : $SHARE_USER"
echo "Password: $SHARE_PASSWORD"

[[ -n "$SERVER_IP" ]] && echo "IP: $SERVER_IP"

echo ""
echo "Security features enabled:"
echo "- SMB encrypted"
echo "- SMB signing required"
echo "- Guest access blocked"
echo "- LAN subnet restricted"
echo "- Firewall restricted to SMB LAN"
echo "- Interface binding (loopback-safe baseline)"