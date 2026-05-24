[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $false)]
    [string]$ShareName = "LabShare",

    [Parameter(Mandatory = $false)]
    [string]$Username = "smbuser",

    [Parameter(Mandatory = $false)]
    [string]$Password = "ChangeMe123!",

    [Parameter(Mandatory = $false)]
    [ValidatePattern("^[A-Z]$")]
    [string]$DriveLetter = "Z"
)

$ErrorActionPreference = "Stop"

$unc = "\\$ServerName\\$ShareName"
$qualifiedUser = "$ServerName\\$Username"

Write-Host "Connecting to $unc as $qualifiedUser"

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($qualifiedUser, $securePassword)

$existing = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Drive $DriveLetter already exists. Removing it first."
    Remove-PSDrive -Name $DriveLetter -Force
}

New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $unc -Credential $credential -Persist | Out-Null

if (-not (Test-Path "$DriveLetter`:\")) {
    throw "Connection failed. Please verify machine name/IP, share name, and credentials."
}

Write-Host "Connected successfully."
Write-Host "Mapped drive: $DriveLetter`:"
Write-Host "UNC path    : $unc"
