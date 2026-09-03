@echo off
chcp 866 >nul 2>nul
title IGRAI - диагностика
cd /d "%~dp0"

echo.
echo   ===== ДИАГНОСТИКА =====
echo.
echo   Папка проекта:
echo     %CD%
echo.
echo   Есть ли index.html:
if exist "index.html" (echo     ДА) else (echo     НЕТ - вы запустили файл не из той папки)
echo.
echo   Есть ли модель ноутбука:
if exist "asus_rog_animated.glb" (echo     ДА) else (echo     НЕТ)
echo.
echo   python в PATH:
where python 2>nul || echo     не найден
echo.
echo   py в PATH:
where py 2>nul || echo     не найден
echo.
echo   node в PATH:
where node 2>nul || echo     не найден
echo.
echo   Папки Python в AppData:
dir /b "%LOCALAPPDATA%\Programs\Python" 2>nul || echo     папки нет
echo.
echo   Версия Python:
python -V 2>nul || echo     не отвечает
echo.
echo   ===== КОНЕЦ =====
echo.
echo   Сфотографируйте или скопируйте это окно и пришлите мне.
echo.
pause
