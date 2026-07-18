\# DownloadFlow



DownloadFlow is a lightweight Windows utility that watches configured download folders, lets you rename newly downloaded files, and automatically organizes them by year and file category.



\## Features



\- Monitors one or more folders

\- Detects completed downloads

\- Ignores temporary browser files such as `.crdownload` and `.part`

\- Displays a small rename window after each download

\- Preserves the original file extension

\- Organizes files by year and category

\- Prevents existing files from being overwritten

\- Starts automatically when you sign in to Windows

\- Uses a simple JSON configuration file

\- Works with any browser or application that downloads files into a monitored folder



\## File Categories



DownloadFlow currently organizes files into:



\- Images

\- Documents

\- Spreadsheets

\- Presentations

\- Audio

\- Videos

\- Archives

\- Installers

\- Fonts

\- Other



\## Requirements



\- Windows 10 or Windows 11

\- PowerShell 7

\- A standard Windows user account

\- Permission to create a scheduled task for the current user



Check your PowerShell version with:



```powershell

pwsh --version

