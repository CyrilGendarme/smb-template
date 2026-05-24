#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME=""
SHARE_NAME="labshare"
USERNAME="smbuser"
PASSWORD="ChangeMe123!"
MOUNT_POINT="/mnt/labshare"

usage() {
  cat <<'EOF'
Usage: connect-smb-share.sh --server-name HOST_OR_IP [options]

Options:
  --server-name HOST        Server hostname or LAN IP (required)
  --share-name NAME         SMB share name (default: labshare)
  --username USER           SMB username (default: smbuser)
  --password PASS           SMB password (default: ChangeMe123!)
  --mount-point PATH        Local mount point (default: /mnt/labshare)
  -h, --help                Show this help message

Example:
  sudo ./connect-smb-share.sh --server-name 192.168.1.10 --share-name LabShare
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-name)
      SERVER_NAME="$2"; shift 2 ;;
    --share-name)
      SHARE_NAME="$2"; shift 2 ;;
    --username)
      USERNAME="$2"; shift 2 ;;
    --password)
      PASSWORD="$2"; shift 2 ;;
    --mount-point)
      MOUNT_POINT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "${SERVER_NAME}" ]]; then
  echo "--server-name is required." >&2
  usage
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (sudo)." >&2
  exit 1
fi

install_client_tools() {
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y cifs-utils
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y cifs-utils
  elif command -v yum >/dev/null 2>&1; then
    yum install -y cifs-utils
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm cifs-utils
  else
    echo "No supported package manager found. Install cifs-utils manually and rerun." >&2
    exit 1
  fi
}

echo "[1/3] Ensuring CIFS client tools are installed"
if ! command -v mount.cifs >/dev/null 2>&1; then
  install_client_tools
fi

echo "[2/3] Creating mount point ${MOUNT_POINT}"
mkdir -p "${MOUNT_POINT}"

UNC="//${SERVER_NAME}/${SHARE_NAME}"

echo "[3/3] Mounting ${UNC} to ${MOUNT_POINT}"
mount -t cifs "${UNC}" "${MOUNT_POINT}" -o "username=${USERNAME},password=${PASSWORD},iocharset=utf8,vers=3.0"

echo "Mounted successfully: ${UNC} -> ${MOUNT_POINT}"
