#!/usr/bin/env bash
set -euo pipefail

SHARE_NAME="${SHARE_NAME:-labshare}"
SHARE_USER="${SHARE_USER:-smbuser}"
SHARE_PATH="${SHARE_PATH:-/srv/samba/labshare}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

echo "[1/6] Removing Samba share from config"

SMB_CONF="/etc/samba/smb.conf"

if grep -q "\[$SHARE_NAME\]" "$SMB_CONF"; then
  sed -i "/\[$SHARE_NAME\]/,/^\[/d" "$SMB_CONF"
  echo "✔ Share removed from smb.conf"
else
  echo "✔ Share not found in config"
fi

echo "[2/6] Removing Samba user"
if pdbedit -L | grep -q "$SHARE_USER"; then
  smbpasswd -x "$SHARE_USER" || true
  echo "✔ Samba user removed"
else
  echo "✔ Samba user not found"
fi

echo "[3/6] Removing system user"
if id "$SHARE_USER" &>/dev/null; then
  userdel "$SHARE_USER"
  echo "✔ Linux user removed"
else
  echo "✔ Linux user not found"
fi

echo "[4/6] Removing share directory (optional)"
if [[ -d "$SHARE_PATH" ]]; then
  rm -rf "$SHARE_PATH"
  echo "✔ Directory removed"
fi

echo "[5/6] Firewall cleanup"
if command -v ufw >/dev/null 2>&1; then
  ufw delete allow from 192.168.1.0/24 to any port 445 proto tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --remove-service=samba >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

echo "[6/6] Restarting Samba"
systemctl restart smbd || service smbd restart || true

echo ""
echo "SMB environment fully removed."