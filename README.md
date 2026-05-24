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