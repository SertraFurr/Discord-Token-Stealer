@echo off
setlocal

set "TARGET_FILE=main.zig"

echo Checking for Zig compiler...

where zig >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Found Zig in PATH.
    set "ZIG_EXE=zig"
    goto :Build
)

if exist "zig_compiler\zig-windows-x86_64-0.13.0\zig.exe" (
    echo Found local Zig compiler.
    set "ZIG_EXE=zig_compiler\zig-windows-x86_64-0.13.0\zig.exe"
    goto :Build
)

if exist "zig.exe" (
    echo Found local Zig compiler in root.
    set "ZIG_EXE=zig.exe"
    goto :Build
)

echo.
echo Error: Zig compiler not found in PATH or local zig_compiler folder.
echo Please install Zig or place the 'zig_compiler' folder here.
pause
exit /b 1

:Build
echo.
echo Building %TARGET_FILE%...
"%ZIG_EXE%" build-exe %TARGET_FILE% -O ReleaseFast -fstrip -target x86_64-windows

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build Failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Build Successful!
if exist "main.exe" (
    echo Created main.exe
)
pause
