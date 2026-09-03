@echo off
chcp 866 >nul 2>nul
title IGRAI - отправить изменения на GitHub
cd /d "%~dp0"

echo.
echo   ==========================================
echo     Отправка изменений на GitHub
echo   ==========================================
echo.

where git >nul 2>nul
if errorlevel 1 goto nogit
if not exist ".git" goto norepo

echo   Что изменилось:
echo.
git status --short
echo.

git diff --quiet
if errorlevel 1 goto haschanges
git diff --cached --quiet
if errorlevel 1 goto haschanges
git ls-files --others --exclude-standard >"%TEMP%\igrai_new.txt"
for %%A in ("%TEMP%\igrai_new.txt") do if %%~zA GTR 0 goto haschanges

echo   Изменений нет - отправлять нечего.
echo.
echo   Проверяю, не осталось ли неотправленных коммитов...
git push
echo.
pause
goto :eof

:haschanges
set /p MSG=  Коротко опишите, что поменяли: 
if "%MSG%"=="" set MSG=Обновление сайта

echo.
git add -A
git commit -m "%MSG%"
if errorlevel 1 goto nocommit

echo.
echo   Отправляю...
git push
if errorlevel 1 goto pushfail

echo.
echo   ==========================================
echo     ГОТОВО.
echo   ==========================================
echo.
echo   Если включён GitHub Pages, сайт обновится
echo   через 1-2 минуты.
echo.
pause
goto :eof

:nocommit
echo.
echo   Коммит не создался. Текст ошибки выше.
echo.
pause
goto :eof

:pushfail
echo.
echo   Отправка не удалась. Возможные причины:
echo   - нет интернета;
echo   - кто-то менял файлы прямо на сайте GitHub.
echo.
echo   Во втором случае выполните в терминале:
echo       git pull --rebase
echo   и запустите этот файл снова.
echo.
pause
goto :eof

:norepo
echo   В этой папке ещё нет репозитория.
echo   Сначала запустите  1-git-setup.bat
echo.
pause
goto :eof

:nogit
echo   Git не установлен.
echo   Скачайте: https://git-scm.com/download/win
echo.
pause
goto :eof
