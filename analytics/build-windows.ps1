$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path .venv-desktop)) {
    $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        & $pythonCommand.Source -3 -m venv .venv-desktop
    } else {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonCommand) {
            throw "Python 3 was not found. Install Python 3.11 or later before building."
        }
        & $pythonCommand.Source -m venv .venv-desktop
    }
}

& .\.venv-desktop\Scripts\python.exe -m pip install -r requirements-build-windows.txt
& .\.venv-desktop\Scripts\python.exe -m PyInstaller `
    --noconfirm `
    --clean `
    --windowed `
    --onedir `
    --name MyMusicAnalytics `
    --add-data "web;web" `
    desktop.py

Write-Host "Built: $PSScriptRoot\dist\MyMusicAnalytics\MyMusicAnalytics.exe"
