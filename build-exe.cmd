@echo off
setlocal

set "ROOT=%~dp0"
set "SRC=%ROOT%src"
set "OUT=%ROOT%dist"
set "DOTNET=C:\Program Files\dotnet\dotnet.exe"

if not exist "%OUT%" mkdir "%OUT%"

if not exist "%DOTNET%" (
    echo Could not find dotnet.exe
    exit /b 1
)

"%DOTNET%" publish "%SRC%\VbsManagerApp.csproj" -c Release -r win-x64 --self-contained true ^
 -p:PublishSingleFile=true ^
 -p:IncludeNativeLibrariesForSelfExtract=true ^
 -o "%OUT%"

exit /b %errorlevel%
