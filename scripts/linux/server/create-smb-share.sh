#!/usr/bin/env bash
set -euo pipefail

SHARE_NAME="${SHARE_NAME:-labshare}"
SHARE_PATH="${SHARE_PATH:-/srv/samba/labshare}"
SHARE_USER="${SHARE_USER:-smbuser}"
SHARE_PASSWORD="${SHARE_PASSWORD:-ChangeMe123!}"
ALLOWED_SUBNET="${ALLOWED_SUBNET:-192.168.1.0/24}"

usage() {
  cat <<'EOF'
Usage: create-smb-share.sh [options]

Options:
  --share-name NAME        SMB share name (default: labshare)
  --share-path PATH        Shared folder path (default: /srv/samba/labshare)
  --share-user USER        Linux + Samba user (default: smbuser)
  --share-password PASS    Samba password (default: ChangeMe123!)
  --allowed-subnet CIDR    Allowed client subnet (default: 192.168.1.0/24)
  -h, --help               Show this help message

Example:
  sudo ./create-smb-share.sh --share-name LabShare --share-path /srv/samba/LabShare
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --share-name)
      SHARE_NAME="$2"; shift 2 ;;
    --share-path)
      SHARE_PATH="$2"; shift 2 ;;
    --share-user)
      SHARE_USER="$2"; shift 2 ;;
    --share-password)
      SHARE_PASSWORD="$2"; shift 2 ;;
    --allowed-subnet)
      ALLOWED_SUBNET="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (sudo)." >&2
  exit 1
fi

install_samba() {
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y samba
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y samba samba-common-tools
  elif command -v yum >/dev/null 2>&1; then
    yum install -y samba samba-common samba-client
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm samba
  else
    echo "No supported package manager found. Install Samba manually and rerun." >&2
    exit 1
  fi
}

echo "[1/7] Ensuring Samba is installed"
if ! command -v smbd >/dev/null 2>&1; then
  install_samba
fi

echo "[2/7] Ensuring Linux user exists: ${SHARE_USER}"
if ! id -u "${SHARE_USER}" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "${SHARE_USER}"
fi

echo "[3/7] Preparing share directory: ${SHARE_PATH}"
mkdir -p "${SHARE_PATH}"
chown -R "${SHARE_USER}:${SHARE_USER}" "${SHARE_PATH}"
chmod -R 2770 "${SHARE_PATH}"

echo "[4/7] Configuring Samba password for ${SHARE_USER}"
( printf '%s\n%s\n' "${SHARE_PASSWORD}" "${SHARE_PASSWORD}" ) | smbpasswd -a -s "${SHARE_USER}"

SMB_CONF="/etc/samba/smb.conf"
BACKUP_PATH="/etc/samba/smb.conf.bak.$(date +%Y%m%d%H%M%S)"

if [[ -f "${SMB_CONF}" ]]; then
  cp "${SMB_CONF}" "${BACKUP_PATH}"
fi

echo "[5/7] Updating Samba config"
if grep -q "^\[${SHARE_NAME}\]" "${SMB_CONF}" 2>/dev/null; then
  awk -v section="${SHARE_NAME}" '
    BEGIN { skip=0 }
    $0 ~ "^\\["section"\\]$" { skip=1; next }
    skip && $0 ~ /^\[/ { skip=0 }
    !skip { print }
  ' "${SMB_CONF}" > "${SMB_CONF}.tmp"
  mv "${SMB_CONF}.tmp" "${SMB_CONF}"
fi

cat <<EOF >> "${SMB_CONF}"

[${SHARE_NAME}]
   path = ${SHARE_PATH}
   browseable = yes
   read only = no
   writable = yes
   valid users = ${SHARE_USER}
   force user = ${SHARE_USER}
   create mask = 0660
   directory mask = 2770
   hosts allow = ${ALLOWED_SUBNET} 127.0.0.1
EOF

echo "[6/7] Testing and restarting Samba service"
testparm -s >/dev/null
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable smbd nmbd 2>/dev/null || true
  systemctl restart smbd
  systemctl restart nmbd 2>/dev/null || true
else
  service smbd restart || service samba restart
fi

echo "[7/7] Opening firewall for Samba (if firewall tool exists)"
if command -v ufw >/dev/null 2>&1; then
  ufw allow from "${ALLOWED_SUBNET}" to any app Samba || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=samba >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"

echo
echo "SMB share template is ready."
echo "Hostname   : $(hostname)"
if [[ -n "${SERVER_IP}" ]]; then
  echo "Server IP  : ${SERVER_IP}"
fi
echo "Share UNC  : //$(hostname)/${SHARE_NAME}"
echo "Username   : ${SHARE_USER}"
echo
echo "Next step: run the client template on the second Linux machine."
