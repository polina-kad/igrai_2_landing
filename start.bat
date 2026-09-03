@echo off
chcp 866 >nul 2>nul
title IGRAI - lokalnyj server
cd /d "%~dp0"

set PORT=8080
set "PY="

echo.
echo   ==========================================
echo     IGRAI - запуск сайта
echo   ==========================================
echo.
echo   Ищу Python...

for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
if not "%PY%"=="" goto found

for /d %%D in ("%ProgramFiles%\Python3*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
if not "%PY%"=="" goto found

set "PF86=%ProgramFiles(x86)%"
for /d %%D in ("%PF86%\Python3*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
if not "%PY%"=="" goto found

for /d %%D in ("C:\Python3*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
if not "%PY%"=="" goto found

if exist "%WINDIR%\py.exe" set "PY=%WINDIR%\py.exe"
if not "%PY%"=="" goto found

goto trynode


:found
echo   Нашла: %PY%
echo.
echo   Адрес сайта:  http://localhost:%PORT%/
echo.
echo   ЭТО ОКНО НЕ ЗАКРЫВАЙТЕ, пока смотрите сайт.
echo   Остановить сервер: Ctrl+C или закрыть это окно.
echo.
echo   ------------------------------------------
echo.
start "" "http://localhost:%PORT%/"
"%PY%" -m http.server %PORT%
echo.
echo   Сервер остановлен.
echo.
pause
goto :eof


:trynode
where node >nul 2>nul
if errorlevel 1 goto nopython
echo   Python не найден, но есть Node.js - запускаю на нём.
echo.
echo   Адрес сайта:  http://localhost:%PORT%/
echo   ЭТО ОКНО НЕ ЗАКРЫВАЙТЕ.
echo.
start "" "http://localhost:%PORT%/"
npx --yes serve -l %PORT% .
echo.
pause
goto :eof


:nopython
echo.
echo   Python не найден.
echo.
echo   Проверила эти места:
echo     %LOCALAPPDATA%\Programs\Python\Python3*
echo     %ProgramFiles%\Python3*
echo     C:\Python3*
echo     %WINDIR%\py.exe
echo.
echo   Что делать:
echo   1. Откройте папку "Загрузки".
echo   2. Запустите файл вида  python-3.13.x-amd64.exe
echo   3. В первом окне снизу поставьте галочку
echo      "Add python.exe to PATH"
echo   4. Нажмите "Install Now" и дождитесь
echo      надписи "Setup was successful".
echo   5. Закройте это окно и запустите start.bat снова.
echo.
pause
goto :eof
