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

echo "[1/8] Installing Samba if needed"
command -v smbd >/dev/null || {
  apt-get update -y
  apt-get install -y samba
}

echo "[2/8] Creating system user"
id "$SHARE_USER" &>/dev/null || useradd -M -s /usr/sbin/nologin "$SHARE_USER"

echo "[3/8] Secure password generation"
if [[ -z "$SHARE_PASSWORD" ]]; then
  SHARE_PASSWORD=$(openssl rand -base64 24)
fi

echo "[4/8] Setting Samba password"
(echo "$SHARE_PASSWORD"; echo "$SHARE_PASSWORD") | smbpasswd -s -a "$SHARE_USER"

echo "[5/8] Preparing directory permissions"
mkdir -p "$SHARE_PATH"
chown "$SHARE_USER:$SHARE_USER" "$SHARE_PATH"
chmod 2770 "$SHARE_PATH"

SMB_CONF="/etc/samba/smb.conf"

echo "[6/8] Hardening Samba global config"
grep -q "\[global\]" "$SMB_CONF" || cat >> "$SMB_CONF" <<EOF

[global]
   server min protocol = SMB2
   server signing = mandatory
   smb encrypt = required
   map to guest = never
   restrict anonymous = 2
EOF

echo "[7/8] Adding secure share config"

# remove existing share block if exists
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

echo "[8/8] Restarting Samba"
systemctl restart smbd || service smbd restart

SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "SECURE SMB READY"
echo "Share: //$HOSTNAME/$SHARE_NAME"
echo "User : $SHARE_USER"
echo "Password: $SHARE_PASSWORD"
[[ -n "$SERVER_IP" ]] && echo "IP: $SERVER_IP"