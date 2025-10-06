@echo off
echo Запуск TileServer-GL...
start cmd /k "tileserver-gl"
timeout /t 3
echo Запуск Flask приложения...
python app.py
pause