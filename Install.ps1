$ErrorActionPreference = "Stop"

$projectFolder = $PSScriptRoot
$installFolder = Join-Path $env:LOCALAPPDATA "DownloadFlow"
$taskName = "DownloadFlow"

$sourceScript = Join-Path $projectFolder "DownloadFlow.ps1"
$sourceConfig = Join-Path $projectFolder "config.json"

if (-not (Test-Path -LiteralPath $sourceScript)) {
    throw "DownloadFlow.ps1 was not found in the project folder."
}

if (-not (Test-Path -LiteralPath $sourceConfig)) {
    throw "config.json was not found in the project folder."
}

$powerShellExecutable = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue

if ($null -eq $powerShellExecutable) {
    throw "PowerShell 7 is required. Install it before running DownloadFlow."
}

Write-Host ""
Write-Host "Installing DownloadFlow..."

New-Item `
    -ItemType Directory `
    -Path $installFolder `
    -Force | Out-Null

Copy-Item `
    -LiteralPath $sourceScript `
    -Destination (Join-Path $installFolder "DownloadFlow.ps1") `
    -Force

Copy-Item `
    -LiteralPath $sourceConfig `
    -Destination (Join-Path $installFolder "config.json") `
    -Force

$installedScript = Join-Path $installFolder "DownloadFlow.ps1"

$action = New-ScheduledTaskAction `
    -Execute $powerShellExecutable.Source `
    -Argument "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$installedScript`""

$trigger = New-ScheduledTaskTrigger `
    -AtLogOn `
    -User $env:USERNAME

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Automatically renames and organizes downloaded files." `
    -Force | Out-Null

Start-ScheduledTask -TaskName $taskName

Write-Host ""
Write-Host "DownloadFlow was installed successfully."
Write-Host "Installation folder: $installFolder"
Write-Host "It will start automatically when you sign in to Windows."
Write-Host ""