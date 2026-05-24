# smb-template

Template scripts to run SMB between two Windows machines connected to the same local network.

## Included scripts

- `scripts/windows/server/create-smb-share.ps1`: creates a local folder share, local SMB user, permissions, and firewall rules on machine A (server).
- `scripts/windows/client/connect-smb-share.ps1`: maps the remote SMB share as a drive on machine B (client).
- `scripts/windows/client/disconnect-smb-share.ps1`: removes the mapped drive on machine B.

## Quick start (2 machines on the same LAN)

### 1) Machine A (SMB server)

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\server\create-smb-share.ps1 \
	-ShareName "LabShare" \
	-SharePath "C:\SMB\LabShare" \
	-ShareUser "smbuser" \
	-SharePassword "ChangeMe123!" \
	-AllowedSubnet "192.168.1.0/24"
```

Take note of:

- Computer name (for example `DESKTOP-ABC123`)
- Share name (for example `LabShare`)
- Username/password used for SMB access

### 2) Machine B (SMB client)

Open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\client\connect-smb-share.ps1 \
	-ServerName "DESKTOP-ABC123" \
	-ShareName "LabShare" \
	-Username "smbuser" \
	-Password "ChangeMe123!" \
	-DriveLetter "Z"
```

If the server name is not resolved by DNS/NetBIOS, use the server LAN IP instead:

```powershell
.\scripts\windows\client\connect-smb-share.ps1 -ServerName "192.168.1.10"
```

### 3) Disconnect client mapping

```powershell
.\scripts\windows\client\disconnect-smb-share.ps1 -DriveLetter "Z"
```

## Security notes

- This is a lab template; change default passwords before regular use.
- Keep both machines on a trusted/private network profile.
- Avoid enabling SMB over public/untrusted networks.

## Linux (Bash) template

Template scripts are also available for Linux-to-Linux SMB over the same local network.

### Included Linux scripts

- `scripts/linux/server/create-smb-share.sh`: installs/configures Samba and creates a share on machine A.
- `scripts/linux/client/connect-smb-share.sh`: mounts the remote SMB share on machine B.
- `scripts/linux/client/disconnect-smb-share.sh`: unmounts the share on machine B.

### 1) Machine A (Linux SMB server)

Run as root (or with `sudo`):

```bash
chmod +x ./scripts/linux/server/create-smb-share.sh
sudo ./scripts/linux/server/create-smb-share.sh \
	--share-name LabShare \
	--share-path /srv/samba/LabShare \
	--share-user smbuser \
	--share-password 'ChangeMe123!' \
	--allowed-subnet 192.168.1.0/24
```

Take note of:

- Hostname (or LAN IP)
- Share name
- SMB username/password

### 2) Machine B (Linux SMB client)

Run as root (or with `sudo`):

```bash
chmod +x ./scripts/linux/client/connect-smb-share.sh
sudo ./scripts/linux/client/connect-smb-share.sh \
	--server-name 192.168.1.10 \
	--share-name LabShare \
	--username smbuser \
	--password 'ChangeMe123!' \
	--mount-point /mnt/labshare
```

If name resolution works in your LAN, you can use hostname instead of IP:

```bash
sudo ./scripts/linux/client/connect-smb-share.sh --server-name my-server-hostname
```

### 3) Disconnect client mount

```bash
chmod +x ./scripts/linux/client/disconnect-smb-share.sh
sudo ./scripts/linux/client/disconnect-smb-share.sh /mnt/labshare
```