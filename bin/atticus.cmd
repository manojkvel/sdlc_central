@echo off
rem Atticus launcher for Windows cmd and PowerShell. Needs Git for Windows (Git Bash) or WSL.
rem Prefer running Atticus inside WSL2 or Git Bash directly; this only forwards to bash.
setlocal
set "RG_BIN=%~dp0atticus"
where bash >nul 2>nul
if errorlevel 1 (
  if exist "%ProgramFiles%\Git\bin\bash.exe" (
    "%ProgramFiles%\Git\bin\bash.exe" "%RG_BIN%" %*
    exit /b %errorlevel%
  )
  echo atticus: bash not found. Install Git for Windows or WSL2, then retry. 1>&2
  exit /b 1
)
bash "%RG_BIN%" %*
exit /b %errorlevel%
