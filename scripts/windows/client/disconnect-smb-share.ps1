[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern("^[A-Z]$")]
    [string]$DriveLetter = "Z"
)

$ErrorActionPreference = "Stop"

$existing = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "No mapped drive found on $DriveLetter`:"
    exit 0
}

Remove-PSDrive -Name $DriveLetter -Force
Write-Host "Disconnected $DriveLetter`:"
