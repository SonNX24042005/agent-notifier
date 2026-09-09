# Automated updater for AI Agent Multi-Monitor Desktop Notifier on Windows
# Requires PowerShell 5.1+

$ErrorActionPreference = "Stop"

Write-Host "=== Cap nhat AI Agent Desktop Notifier len ban moi nhat ===" -ForegroundColor Cyan

$ScriptDir = $PSScriptRoot
if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "install.ps1"))) {
    Write-Host "=== Cap nhat tu thu muc ma nguon cuc bo ===" -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "install.ps1")
    exit 0
}

$TempZipDir = Join-Path $env:TEMP ("anoti_update_" + (Get-Random))
New-Item -ItemType Directory -Force -Path $TempZipDir | Out-Null

$ZipPath = Join-Path $TempZipDir "repo.zip"
$ZipUrl = "https://github.com/SonNX24042005/agent-notifier/archive/refs/heads/master.zip"

try {
    Write-Host "Dang tai ban cap nhat tu GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    Expand-Archive -Path $ZipPath -DestinationPath $TempZipDir -Force
    $SourceDir = Join-Path $TempZipDir "agent-notifier-master"
    $InstallScript = Join-Path $SourceDir "install.ps1"
    
    if (Test-Path $InstallScript) {
        & powershell -ExecutionPolicy Bypass -File $InstallScript
    } else {
        Write-Host "[ERROR] Khong tim thay install.ps1 trong ban cap nhat." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] Loi trong qua trinh cap nhat: $_" -ForegroundColor Red
    exit 1
} finally {
    Remove-Item -Path $TempZipDir -Recurse -Force -ErrorAction SilentlyContinue
}
