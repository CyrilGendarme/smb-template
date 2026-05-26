[CmdletBinding()]
param(
    [string]$ShareName = "LabShare",
    [string]$SharePath = "C:\SMB\LabShare",
    [string]$ShareUser = "smbuser",
    [string]$SharePassword = "",
    [string]$AllowedSubnet = "192.168.1.0/24"
)

$ErrorActionPreference = "Stop"

# Require admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run as Administrator."
}

Write-Host "[1/8] Ensuring share folder exists"
if (-not (Test-Path $SharePath)) {
    New-Item -ItemType Directory -Path $SharePath -Force | Out-Null
}

Write-Host "[2/8] Generating secure password if not provided"
if (-not $SharePassword) {
    Add-Type -AssemblyName System.Web
    $SharePassword = [System.Web.Security.Membership]::GeneratePassword(24,5)
}

$securePassword = ConvertTo-SecureString $SharePassword -AsPlainText -Force

Write-Host "[3/8] Ensuring local user exists"
if (-not (Get-LocalUser -Name $ShareUser -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $ShareUser `
        -Password $securePassword `
        -PasswordNeverExpires:$false `
        -AccountNeverExpires:$false | Out-Null
}

$account = "$env:COMPUTERNAME\$ShareUser"

Write-Host "[4/8] NTFS permissions (least privilege)"
icacls $SharePath /grant "${account}:(OI)(CI)M" /T | Out-Null

Write-Host "[5/8] Creating SMB share (no full access)"
if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $ShareName -Path $SharePath -ChangeAccess $account | Out-Null
}

Write-Host "[6/8] Enabling SMB encryption"
Set-SmbShare -Name $ShareName -EncryptData $true

Write-Host "[7/8] Hardening SMB server config"
Set-SmbServerConfiguration -EnableGuestAccess $false -Force | Out-Null

# Optional NTLM hardening (lab-safe but may break legacy clients)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
    -Name "LmCompatibilityLevel" -Value 5

Write-Host "[8/8] Firewall rule (scoped)"
New-NetFirewallRule `
    -DisplayName "SMB 445 $ShareName" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 445 `
    -RemoteAddress $AllowedSubnet `
    -Profile Private | Out-Null

Write-Host ""
Write-Host "SMB READY (SECURED)"
Write-Host "Share: \\$env:COMPUTERNAME\$ShareName"
Write-Host "User : $account"
Write-Host "Password: $SharePassword"