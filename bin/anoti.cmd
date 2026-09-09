@echo off
setlocal
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0anoti" %*
) else (
    py -3 "%~dp0anoti" %*
)
