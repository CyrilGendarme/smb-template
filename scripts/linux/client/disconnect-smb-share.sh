#!/usr/bin/env bash
set -euo pipefail

MOUNT_POINT="${1:-/mnt/labshare}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (sudo)." >&2
  exit 1
fi

if mountpoint -q "${MOUNT_POINT}"; then
  umount "${MOUNT_POINT}"
  echo "Unmounted ${MOUNT_POINT}"
else
  echo "No SMB mount found at ${MOUNT_POINT}"
fi
