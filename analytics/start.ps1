$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path .venv)) {
    python -m venv .venv
}

& .\.venv\Scripts\python.exe -m pip install -q -r requirements.txt
if ($env:MYMUSIC_ANALYTICS_NO_BROWSER -ne "1") {
    Start-Process "http://127.0.0.1:8766"
}
& .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8766
