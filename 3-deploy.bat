@echo off
chcp 866 >nul 2>nul
title IGRAI - выкладка на сервер
cd /d "%~dp0"

set "BASH="

echo.
echo   ==========================================
echo     IGRAI - выкладка на сервер
echo   ==========================================
echo.

if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not "%BASH%"=="" goto run

set "PF86=%ProgramFiles(x86)%"
if exist "%PF86%\Git\bin\bash.exe" set "BASH=%PF86%\Git\bin\bash.exe"
if not "%BASH%"=="" goto run

if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not "%BASH%"=="" goto run

goto nobash


:run
if not exist "deploy\target.env" goto noconf
echo   Git Bash: %BASH%
echo.
"%BASH%" -lc "./deploy/deploy.sh"
echo.
pause
goto :eof


:noconf
echo   Нет файла deploy\target.env
echo.
echo   Скопируйте deploy\target.env.example в deploy\target.env
echo   и впишите адрес сервера и пользователя.
echo.
pause
goto :eof


:nobash
echo   Не найден Git Bash - он идёт вместе с Git для Windows.
echo.
echo   Скачайте:  https://git-scm.com/download/win
echo   Установка - всё по умолчанию.
echo.
echo   Потом закройте это окно и запустите файл снова.
echo.
pause
goto :eof
