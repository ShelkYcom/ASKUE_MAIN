@echo off
setlocal
rem Всегда работаем из папки, где лежит start.bat
cd /d "%~dp0"

echo Запуск TileServer-GL...
rem Явно укажем файл, порт и привязку ко всем интерфейсам
set TS_CMD=tileserver-gl --mbtiles "%~dp0russia.mbtiles" --port 8080 --bind 0.0.0.0

rem Запускаем в отдельном окне, виден лог; окно назовем для наглядности
start "TileServerGL" cmd /k "%TS_CMD%"

rem Небольшая пауза, чтобы tileserver успел подняться
timeout /t 5 >nul

echo Запуск Flask приложения...
python "%~dp0app.py"

endlocal
pause
