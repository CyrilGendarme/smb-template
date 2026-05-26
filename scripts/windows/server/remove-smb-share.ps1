[CmdletBinding()]
param(
    [string]$ShareName = "LabShare",
    [string]$ShareUser = "smbuser",
    [string]$SharePath = "C:\SMB\LabShare"
)

$ErrorActionPreference = "Stop"

# Require admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run as Administrator."
}

Write-Host "[1/6] Removing SMB share"

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($share) {
    Remove-SmbShare -Name $ShareName -Force
    Write-Host "✔ SMB share removed"
} else {
    Write-Host "✔ SMB share not found"
}

Write-Host "[2/6] Removing firewall rules"

Get-NetFirewallRule |
    Where-Object DisplayName -like "*$ShareName*" |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

Write-Host "[3/6] Removing SMB encryption config (optional cleanup)"
try {
    Set-SmbShare -Name $ShareName -EncryptData $false -ErrorAction SilentlyContinue
} catch {}

Write-Host "[4/6] Removing local user"

if (Get-LocalUser -Name $ShareUser -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $ShareUser
    Write-Host "✔ Local user removed"
} else {
    Write-Host "✔ User not found"
}

Write-Host "[5/6] Cleaning NTFS permissions (optional reset)"
if (Test-Path $SharePath) {
    icacls $SharePath /reset /T | Out-Null
}

Write-Host "[6/6] Done"

Write-Host ""
Write-Host "SMB environment fully removed."