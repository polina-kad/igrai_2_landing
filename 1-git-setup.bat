@echo off
chcp 866 >nul 2>nul
title IGRAI - настройка Git (один раз)
cd /d "%~dp0"

set REPO=https://github.com/polina-kad/igrai_2_landing.git

echo.
echo   ==========================================
echo     Настройка Git - выполняется один раз
echo   ==========================================
echo.

where git >nul 2>nul
if errorlevel 1 goto nogit

echo   Git найден.
echo.

rem ---------- имя и email для коммитов ----------
for /f "delims=" %%N in ('git config --global user.name 2^>nul') do set "GNAME=%%N"
if not "%GNAME%"=="" goto haveemail

echo   Git ещё не знает, кто вы. Это попадёт в подпись коммитов.
echo.
set /p GNAME=  Ваше имя (например Polina Kad): 
if "%GNAME%"=="" set GNAME=Polina Kad
git config --global user.name "%GNAME%"

:haveemail
for /f "delims=" %%E in ('git config --global user.email 2^>nul') do set "GMAIL=%%E"
if not "%GMAIL%"=="" goto initrepo

set /p GMAIL=  Ваш email с GitHub: 
if "%GMAIL%"=="" goto noemail
git config --global user.email "%GMAIL%"

:initrepo
echo.
if exist ".git" goto haverepo
echo   Создаю репозиторий в этой папке...
git init
git branch -M main
goto setremote

:haverepo
echo   Репозиторий здесь уже есть - пропускаю git init.

:setremote
echo   Прописываю адрес на GitHub...
git remote remove origin >nul 2>nul
git remote add origin %REPO%

echo.
echo   Добавляю все файлы...
git add -A

echo.
echo   Делаю коммит...
git commit -m "Лендинг IGRAI: 3D-анимация ноутбука по скроллу"
if errorlevel 1 echo   (нечего коммитить - видимо, уже было сделано)

echo.
echo   ------------------------------------------
echo   Отправляю на GitHub.
echo   Сейчас может открыться браузер с входом
echo   в GitHub - нажмите там Authorize.
echo   ------------------------------------------
echo.
git push -u origin main
if errorlevel 1 goto pushfail

echo.
echo   ==========================================
echo     ГОТОВО. Файлы на GitHub.
echo   ==========================================
echo.
echo   Дальше для новых изменений запускайте
echo   файл  2-otpravit-izmeneniya.bat
echo.
pause
goto :eof


:pushfail
echo.
echo   ==========================================
echo   GitHub отказался принять отправку.
echo   ==========================================
echo.
echo   Обычно это значит, что в репозитории уже
echo   есть файлы - например, вы заливали их
echo   раньше через сайт.
echo.
echo   Можно перезаписать содержимое репозитория
echo   тем, что лежит в этой папке.
echo.
echo   ВНИМАНИЕ: всё, что сейчас на GitHub в ветке
echo   main, будет заменено локальной версией.
echo   История того, что там было, потеряется.
echo.
set /p ANS=  Перезаписать? Введите y и Enter (или просто Enter чтобы отменить): 
if /i not "%ANS%"=="y" goto cancelled

echo.
git push -u origin main --force
if errorlevel 1 goto stillbad
echo.
echo   ГОТОВО. Файлы на GitHub.
echo.
pause
goto :eof

:cancelled
echo.
echo   Отменено, ничего не перезаписано.
echo   Коммит остался у вас локально - отправить
echo   можно позже.
echo.
pause
goto :eof

:stillbad
echo.
echo   Всё равно не получилось. Скопируйте текст
echo   выше и пришлите мне - разберёмся.
echo.
pause
goto :eof


:nogit
echo   Git не установлен.
echo.
echo   Скачайте его здесь:  https://git-scm.com/download/win
echo   Установка - всё по умолчанию, ничего менять не нужно.
echo.
echo   Потом закройте это окно и запустите файл снова.
echo.
pause
goto :eof

:noemail
echo.
echo   Email не введён - без него git не сделает коммит.
echo   Запустите файл ещё раз.
echo.
pause
goto :eof
