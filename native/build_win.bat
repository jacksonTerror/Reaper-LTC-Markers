@echo off
setlocal
set ROOT=%~dp0
REM Standalone repo: libltc is a git submodule at ../libltc
set LIB=%ROOT%..\libltc\src
set GCC=C:\msys64\ucrt64\bin\gcc.exe

if not exist "%GCC%" set GCC=C:\msys64\mingw64\bin\gcc.exe
if not exist "%LIB%\ltc.c" (
  echo libltc sources not found at %LIB%
  echo Run: git submodule update --init --recursive
  exit /b 1
)
if not exist "%GCC%" (
  echo gcc not found. Install MSYS2 UCRT64 toolchain, or use GitHub Actions artifacts.
  exit /b 1
)

mkdir "%ROOT%bin" 2>nul
mkdir "%ROOT%bin\windows" 2>nul
echo Building with %GCC%
"%GCC%" -O2 -std=c11 -mwindows -I"%ROOT%include" -I"%LIB%" "%ROOT%src\ltc_scan_lib.c" "%ROOT%src\ltc_scan_cli.c" "%LIB%\ltc.c" "%LIB%\decoder.c" "%LIB%\encoder.c" "%LIB%\timecode.c" -o "%ROOT%bin\ltc_scan.exe"
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)
copy /Y "%ROOT%bin\ltc_scan.exe" "%ROOT%bin\windows\ltc_scan.exe" >nul
echo OK: %ROOT%bin\ltc_scan.exe
exit /b 0
