@echo off
chcp 866 >nul 2>nul
title IGRAI - диагностика сервера
cd /d "%~dp0"

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not "%BASH%"=="" goto run
set "PF86=%ProgramFiles(x86)%"
if exist "%PF86%\Git\bin\bash.exe" set "BASH=%PF86%\Git\bin\bash.exe"
if not "%BASH%"=="" goto run
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not "%BASH%"=="" goto run
goto nobash

:run
echo.
echo   Собираю сведения о сервере. Ничего не меняю.
echo.
"%BASH%" -lc "./deploy/diagnose.sh"
echo.
echo   Отчёт сохранён: deploy\server-report.txt
echo   Скажите в чате "готово" - я его прочитаю сама.
echo.
pause
goto :eof

:nobash
echo   Не найден Git Bash. Скачайте: https://git-scm.com/download/win
echo.
pause
