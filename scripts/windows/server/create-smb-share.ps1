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

Write-Host "[1/10] Ensuring share folder exists"
if (-not (Test-Path $SharePath)) {
    New-Item -ItemType Directory -Path $SharePath -Force | Out-Null
}

Write-Host "[2/10] Generating secure password if not provided"
if (-not $SharePassword) {
    Add-Type -AssemblyName System.Web
    $SharePassword = [System.Web.Security.Membership]::GeneratePassword(24,5)
}

$securePassword = ConvertTo-SecureString $SharePassword -AsPlainText -Force

Write-Host "[3/10] Ensuring local user exists"
if (-not (Get-LocalUser -Name $ShareUser -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $ShareUser `
        -Password $securePassword `
        -PasswordNeverExpires:$false `
        -AccountNeverExpires:$false | Out-Null
}

$account = "$env:COMPUTERNAME\$ShareUser"

Write-Host "[4/10] NTFS permissions (least privilege)"
icacls $SharePath /grant "${account}:(OI)(CI)M" /T | Out-Null

Write-Host "[5/10] Creating SMB share"
if (-not (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $ShareName -Path $SharePath -ChangeAccess $account | Out-Null
}

Write-Host "[6/10] Enabling SMB encryption"
Set-SmbShare -Name $ShareName -EncryptData $true

Write-Host "[7/10] SMB hardening"
Set-SmbServerConfiguration -EnableGuestAccess $false -Force | Out-Null

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
    -Name "LmCompatibilityLevel" -Value 5


# =========================
# 🧠 NEW: NETWORK SAFETY MODE
# =========================

Write-Host "[8/10] Checking network profile"

$profiles = Get-NetConnectionProfile

$publicNetworks = $profiles | Where-Object NetworkCategory -eq "Public"
$privateNetworks = $profiles | Where-Object NetworkCategory -eq "Private"

# Disable SMB if ANY interface is Public
if ($publicNetworks) {
    Write-Host "⚠ Public network detected → DISABLING SMB access"

    Get-NetFirewallRule |
        Where-Object DisplayName -like "*SMB 445*" |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue

    Get-NetFirewallRule |
        Where-Object DisplayGroup -like "*File*" |
        Disable-NetFirewallRule -ErrorAction SilentlyContinue
}
else {
    Write-Host "✔ Private network only → enabling SMB access"

    Get-NetFirewallRule |
        Where-Object DisplayGroup -like "*File*" |
        Enable-NetFirewallRule -ErrorAction SilentlyContinue
}


Write-Host "[9/10] Firewall rule (Private only + subnet scoped)"
$ruleName = "SMB 445 $ShareName"

if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 445 `
        -RemoteAddress $AllowedSubnet `
        -Profile Private | Out-Null
}

Write-Host "[10/10] Final validation"

$serverIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","Wi-Fi*" -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ""
Write-Host "SMB READY (TRAVEL SAFE MODE)"
Write-Host "Share : \\$env:COMPUTERNAME\$ShareName"
Write-Host "User  : $account"
Write-Host "Pass  : $SharePassword"

if ($serverIp) {
    Write-Host "IP    : $serverIp"
}

Write-Host ""
Write-Host "Security mode:"
Write-Host "- SMB disabled on Public networks"
Write-Host "- SMB enabled only on Private networks"
Write-Host "- Firewall scoped to subnet + Private profile"