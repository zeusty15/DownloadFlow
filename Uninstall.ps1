$ErrorActionPreference = "Stop"

$taskName = "DownloadFlow"
$installFolder = Join-Path $env:LOCALAPPDATA "DownloadFlow"

Write-Host ""
Write-Host "Uninstalling DownloadFlow..."

$task = Get-ScheduledTask `
    -TaskName $taskName `
    -ErrorAction SilentlyContinue

if ($null -ne $task) {
    Stop-ScheduledTask `
        -TaskName $taskName `
        -ErrorAction SilentlyContinue

    Unregister-ScheduledTask `
        -TaskName $taskName `
        -Confirm:$false
}

Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -like "*DownloadFlow.ps1*"
    } |
    ForEach-Object {
        Stop-Process `
            -Id $_.ProcessId `
            -Force `
            -ErrorAction SilentlyContinue
    }

if (Test-Path -LiteralPath $installFolder) {
    Remove-Item `
        -LiteralPath $installFolder `
        -Recurse `
        -Force
}

Write-Host ""
Write-Host "DownloadFlow was uninstalled successfully."
Write-Host ""