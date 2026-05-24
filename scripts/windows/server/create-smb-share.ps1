[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ShareName = "LabShare",

    [Parameter(Mandatory = $false)]
    [string]$SharePath = "C:\\SMB\\LabShare",

    [Parameter(Mandatory = $false)]
    [string]$ShareUser = "smbuser",

    [Parameter(Mandatory = $false)]
    [string]$SharePassword = "ChangeMe123!",

    [Parameter(Mandatory = $false)]
    [string]$AllowedSubnet = "192.168.1.0/24"
)

$ErrorActionPreference = "Stop"

# SMB share creation needs administrator privileges.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run this script from an elevated PowerShell session (Run as administrator)."
}

Write-Host "[1/6] Ensuring share folder exists: $SharePath"
if (-not (Test-Path -LiteralPath $SharePath)) {
    New-Item -ItemType Directory -Path $SharePath -Force | Out-Null
}

Write-Host "[2/6] Ensuring local user exists: $ShareUser"
$localUser = Get-LocalUser -Name $ShareUser -ErrorAction SilentlyContinue
if (-not $localUser) {
    $securePassword = ConvertTo-SecureString -String $SharePassword -AsPlainText -Force
    New-LocalUser -Name $ShareUser -Password $securePassword -PasswordNeverExpires -AccountNeverExpires | Out-Null
}

$account = "${env:COMPUTERNAME}\\$ShareUser"

Write-Host "[3/6] Granting NTFS Modify rights for $account"
& icacls $SharePath /grant "${account}:(OI)(CI)M" /T | Out-Null

Write-Host "[4/6] Ensuring SMB share exists: $ShareName"
$existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if (-not $existingShare) {
    New-SmbShare -Name $ShareName -Path $SharePath -FullAccess $account | Out-Null
}

Write-Host "[5/6] Enabling File and Printer Sharing firewall group on Private profile"
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True -Profile Private | Out-Null

Write-Host "[6/6] Creating scoped SMB firewall rule (TCP 445) for $AllowedSubnet"
$ruleName = "Allow SMB 445 from $AllowedSubnet"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existingRule) {
    New-NetFirewallRule \
        -DisplayName $ruleName \
        -Direction Inbound \
        -Action Allow \
        -Protocol TCP \
        -LocalPort 445 \
        -RemoteAddress $AllowedSubnet \
        -Profile Private | Out-Null
}

$serverIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","Wi-Fi*" -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ""
Write-Host "SMB share template is ready."
Write-Host "ComputerName : $env:COMPUTERNAME"
if ($serverIp) { Write-Host "Server IP    : $serverIp" }
Write-Host "Share UNC    : \\$env:COMPUTERNAME\\$ShareName"
Write-Host "Username     : $account"
Write-Host ""
Write-Host "Next step: run the client template on the second machine."
