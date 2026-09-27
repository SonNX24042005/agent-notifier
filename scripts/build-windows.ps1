# Automated Windows (.exe) standalone and installer builder for AI Agent Desktop Notifier
param (
    [switch]$SkipInstaller = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoDir = Split-Path -Parent $ScriptDir
Set-Location $RepoDir

Write-Host "=== 1. Checking build prerequisites ===" -ForegroundColor Cyan

# Check Python and PyInstaller
$PythonExe = "python"
if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) {
    $PythonExe = "py"
    if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) {
        Write-Error "Python is required to build Windows binaries. Please install Python 3.8+."
        exit 1
    }
}

Write-Host "Checking PyInstaller..."
& $PythonExe -m pip install --quiet --upgrade pyinstaller

$DistDir = Join-Path $RepoDir "dist"
$BuildDir = Join-Path $RepoDir "build"
$AnotiDist = Join-Path $DistDir "anoti"

if (Test-Path $AnotiDist) {
    Remove-Item -Recurse -Force $AnotiDist
}

Write-Host "=== 2. Building standalone binaries with PyInstaller ===" -ForegroundColor Cyan

# Build anoti (CLI tool, console mode)
Write-Host "Compiling anoti.exe..."
& $PythonExe -m PyInstaller `
    --noconfirm `
    --onedir `
    --console `
    --name "anoti" `
    --distpath $DistDir `
    --workpath $BuildDir `
    (Join-Path $RepoDir "bin\anoti")

# Build multi-desktop-notify (GUI overlay engine, windowed mode to hide console window)
Write-Host "Compiling multi-desktop-notify.exe..."
& $PythonExe -m PyInstaller `
    --noconfirm `
    --onedir `
    --windowed `
    --name "multi-desktop-notify" `
    --distpath (Join-Path $BuildDir "engine_dist") `
    --workpath $BuildDir `
    (Join-Path $RepoDir "bin\multi-desktop-notify.py")

# Merge multi-desktop-notify into dist\anoti directory
$EngineDistDir = Join-Path $BuildDir "engine_dist\multi-desktop-notify"
if (Test-Path $EngineDistDir) {
    Get-ChildItem -Path $EngineDistDir | ForEach-Object {
        $Dest = Join-Path $AnotiDist $_.Name
        if (-not (Test-Path $Dest)) {
            Copy-Item -Path $_.FullName -Destination $Dest -Recurse -Force
        }
    }
}

# Copy hooks folder
$HooksTarget = Join-Path $AnotiDist "hooks"
if (-not (Test-Path $HooksTarget)) {
    New-Item -ItemType Directory -Path $HooksTarget | Out-Null
}
Copy-Item -Path (Join-Path $RepoDir "hooks\*") -Destination $HooksTarget -Recurse -Force

Write-Host "[OK] Standalone distribution created at: $AnotiDist" -ForegroundColor Green

# 3. Create portable zip package
$ZipOutput = Join-Path $DistDir "anoti-windows-portable.zip"
if (Test-Path $ZipOutput) {
    Remove-Item -Force $ZipOutput
}
Write-Host "Compressing portable zip package: $ZipOutput..."
Compress-Archive -Path "$AnotiDist\*" -DestinationPath $ZipOutput -Force
Write-Host "[OK] Created portable zip package." -ForegroundColor Green

# 4. Build Inno Setup installer if available and not skipped
if (-not $SkipInstaller) {
    Write-Host "=== 3. Building Inno Setup installer ===" -ForegroundColor Cyan
    $IsccCandidates = @(
        (Get-Command "iscc.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
        "${env:ProgramFiles}\Inno Setup 6\iscc.exe",
        "${env:LOCALAPPDATA}\Programs\Inno Setup 6\iscc.exe"
    )

    $IsccExe = $IsccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($IsccExe) {
        Write-Host "Found Inno Setup compiler: $IsccExe"
        $IssFile = Join-Path $ScriptDir "installer.iss"
        & $IsccExe $IssFile
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Inno Setup compiler failed with exit code $LASTEXITCODE."
            exit $LASTEXITCODE
        }
        Write-Host "[OK] Windows installer built successfully at: $DistDir\anoti-setup.exe" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Inno Setup compiler (iscc.exe) not found. Skipped installer .exe generation." -ForegroundColor Yellow
        Write-Host "       (To build the installer, install Inno Setup 6 or run 'choco install innosetup')." -ForegroundColor Yellow
    }
}

Write-Host "=== Build completed! ===" -ForegroundColor Green
