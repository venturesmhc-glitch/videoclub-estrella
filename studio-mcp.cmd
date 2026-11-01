@echo off
rem Launches the newest StudioMCP.exe bundled with Roblox Studio.
rem Studio updates change the version-* folder, so resolve it at launch time.
setlocal
set "BEST="
for /f "delims=" %%i in ('dir /b /s /o-d "%LOCALAPPDATA%\Roblox\Versions\StudioMCP.exe" 2^>nul') do (
  if not defined BEST set "BEST=%%i"
)
if not defined BEST (
  echo StudioMCP.exe not found under %LOCALAPPDATA%\Roblox\Versions 1>&2
  exit /b 1
)
"%BEST%" --stdio
