Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Relance automatiquement le script en mode STA,
# nécessaire pour afficher correctement les fenêtres.
if ([Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
    $powerShellExe = (Get-Process -Id $PID).Path

    Start-Process -FilePath $powerShellExe -ArgumentList @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-STA"
        "-File", "`"$PSCommandPath`""
    )

    exit
}

$configPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Fichier config.json introuvable : $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw |
    ConvertFrom-Json

$downloadFolders = foreach ($folder in $config.folders) {
    Join-Path $env:USERPROFILE $folder
}

$scanIntervalSeconds = [int]$config.scanIntervalSeconds
$sortByYear = [bool]$config.sortByYear
$askForRename = [bool]$config.askForRename
$temporaryExtensions = @(
    ".crdownload"
    ".part"
    ".tmp"
    ".download"
)

function Get-FileCategory {
    param(
        [string]$Extension
    )

    switch ($Extension.ToLowerInvariant()) {
        { $_ -in ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".bmp", ".tif", ".tiff", ".heic" } {
            return "Images"
        }

        { $_ -in ".pdf", ".doc", ".docx", ".txt", ".rtf", ".odt" } {
            return "Documents"
        }

        { $_ -in ".xls", ".xlsx", ".csv", ".ods" } {
            return "Spreadsheets"
        }

        { $_ -in ".ppt", ".pptx", ".odp" } {
            return "Presentations"
        }

        { $_ -in ".mp3", ".wav", ".flac", ".aac", ".m4a", ".ogg", ".wma" } {
            return "Audio"
        }

        { $_ -in ".mp4", ".mkv", ".avi", ".mov", ".webm", ".m4v", ".wmv" } {
            return "Videos"
        }

        { $_ -in ".zip", ".rar", ".7z", ".tar", ".gz" } {
            return "Archives"
        }

        { $_ -in ".exe", ".msi", ".msix", ".appx" } {
            return "Installateurs"
        }

        { $_ -in ".ttf", ".otf", ".woff", ".woff2" } {
            return "Fonts"
        }

        default {
            return "Other"
        }
    }
}

function Test-FileReady {
    param(
        [string]$Path
    )

    $previousSize = -1

    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $false
        }

        try {
            $file = Get-Item -LiteralPath $Path -ErrorAction Stop
            $currentSize = $file.Length

            $stream = [System.IO.File]::Open(
                $Path,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::None
            )

            $stream.Close()

            if ($currentSize -eq $previousSize) {
                return $true
            }

            $previousSize = $currentSize
        }
        catch {
            # Le navigateur utilise encore le fichier.
        }

        Start-Sleep -Seconds 1
    }

    return $false
}

function Remove-InvalidFileNameCharacters {
    param(
        [string]$Name
    )

    $cleanName = $Name

    foreach ($character in [System.IO.Path]::GetInvalidFileNameChars()) {
        $cleanName = $cleanName.Replace($character, "_")
    }

    return $cleanName.Trim().TrimEnd(".")
}

function Show-RenameWindow {
    param(
        [System.IO.FileInfo]$File
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "New download"
    $form.Size = New-Object System.Drawing.Size(570, 260)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(515, 25)
    $titleLabel.Font = New-Object System.Drawing.Font(
        "Segoe UI",
        11,
        [System.Drawing.FontStyle]::Bold
    )
    $titleLabel.Text = "New downloaded file"
    $form.Controls.Add($titleLabel)

    $fileLabel = New-Object System.Windows.Forms.Label
    $fileLabel.Location = New-Object System.Drawing.Point(20, 55)
    $fileLabel.Size = New-Object System.Drawing.Size(515, 35)
    $fileLabel.Text = $File.Name
    $form.Controls.Add($fileLabel)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Location = New-Object System.Drawing.Point(20, 98)
    $nameLabel.Size = New-Object System.Drawing.Size(180, 22)
    $nameLabel.Text = "New name:"
    $form.Controls.Add($nameLabel)

    $nameTextBox = New-Object System.Windows.Forms.TextBox
    $nameTextBox.Location = New-Object System.Drawing.Point(20, 122)
    $nameTextBox.Size = New-Object System.Drawing.Size(515, 27)
    $nameTextBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $nameTextBox.SelectAll()
    $form.Controls.Add($nameTextBox)

    $renameButton = New-Object System.Windows.Forms.Button
    $renameButton.Location = New-Object System.Drawing.Point(20, 170)
    $renameButton.Size = New-Object System.Drawing.Size(175, 35)
    $renameButton.Text = "Rename and organize"
    $renameButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($renameButton)

    $keepButton = New-Object System.Windows.Forms.Button
    $keepButton.Location = New-Object System.Drawing.Point(202, 170)
    $keepButton.Size = New-Object System.Drawing.Size(160, 35)
    $keepButton.Text = "Keep name and organize"
    $keepButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $form.Controls.Add($keepButton)

    $leaveButton = New-Object System.Windows.Forms.Button
    $leaveButton.Location = New-Object System.Drawing.Point(369, 170)
    $leaveButton.Size = New-Object System.Drawing.Size(166, 35)
    $leaveButton.Text = "Leave here"
    $leaveButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($leaveButton)

    $form.AcceptButton = $renameButton
    $form.CancelButton = $leaveButton

    $nameTextBox.Focus()

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{
            Action   = "Move"
            BaseName = $nameTextBox.Text
        }
    }

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        return @{
            Action   = "Move"
            BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        }
    }

    return @{
        Action   = "Leave"
        BaseName = ""
    }
}

function Get-AvailableDestination {
    param(
        [string]$Folder,
        [string]$BaseName,
        [string]$Extension
    )

    $destination = Join-Path $Folder ($BaseName + $Extension)
    $number = 2

    while (Test-Path -LiteralPath $destination) {
        $destination = Join-Path $Folder (
            "{0} ({1}){2}" -f $BaseName, $number, $Extension
        )

        $number++
    }

    return $destination
}

$knownFiles = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

# Les fichiers déjà présents au lancement ne déclenchent pas de fenêtre.
foreach ($folder in $downloadFolders) {
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            [void]$knownFiles.Add($_.FullName)
        }
}

Write-Host ""
Write-Host "DownloadFlow is running."
Write-Host "Configured download folders are now being monitored."
Write-Host "Keep this window open."
Write-Host ""

while ($true) {
    foreach ($folder in $downloadFolders) {
        $files = Get-ChildItem `
            -LiteralPath $folder `
            -File `
            -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            if ($temporaryExtensions -contains $file.Extension.ToLowerInvariant()) {
                continue
            }

            if (-not $knownFiles.Add($file.FullName)) {
                continue
            }

            if (-not (Test-FileReady -Path $file.FullName)) {
                continue
            }

            $file = Get-Item -LiteralPath $file.FullName -ErrorAction SilentlyContinue

            if ($null -eq $file) {
                continue
            }

            if ($askForRename) {
                $choice = Show-RenameWindow -File $file
            }
            else {
                $choice = @{
                    Action   = "Move"
                    BaseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                }
            }

            if ($choice.Action -eq "Leave") {
                continue
            }

            $baseName = Remove-InvalidFileNameCharacters -Name $choice.BaseName

            if ([string]::IsNullOrWhiteSpace($baseName)) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            }

            $category = Get-FileCategory -Extension $file.Extension

	    if ($sortByYear) {
                  $year = (Get-Date).Year.ToString()
                  $destinationFolder = Join-Path $folder $year
                  $destinationFolder = Join-Path $destinationFolder $category
            }
            else {
                $destinationFolder = Join-Path $folder $category
    }

            New-Item `
                -ItemType Directory `
                -Path $destinationFolder `
                -Force | Out-Null

            $destination = Get-AvailableDestination `
                -Folder $destinationFolder `
                -BaseName $baseName `
                -Extension $file.Extension.ToLowerInvariant()

            try {
                Move-Item `
                    -LiteralPath $file.FullName `
                    -Destination $destination `
                    -ErrorAction Stop
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Impossible de ranger le fichier :`n$($_.Exception.Message)",
                    "Erreur",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }
    }

    Start-Sleep -Seconds $scanIntervalSeconds
}