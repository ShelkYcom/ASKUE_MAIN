@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

echo ============================================================
echo   Импорт точек из Excel в SQLite (app.sqlite)
echo   Проект: %CD%
echo ============================================================

REM Параметры: [путь_к_excel] [--replace]
set "EXCEL=%~1"
set "FLAG=%~2"
if "%EXCEL%"=="" set "EXCEL=.\data\statuses.xlsx"

if /I "%FLAG%"=="--REPLACE" (
  set "REPLACE=--replace"
) else (
  set "REPLACE="
)

if not exist "%EXCEL%" (
  echo [ОШИБКА] Не найден Excel-файл: "%EXCEL%"
  pause
  exit /b 1
)

if not exist ".\data" mkdir ".\data"

echo [INFO] Инициализация БД...
call node .\src\db-init.js || goto :fail

echo [INFO] Приводим схему к уникальности (name, lat, lon)...
call node .\src\migrate-name-latlon-only.js || goto :fail

echo [INFO] Импорт: "%EXCEL%" %REPLACE%
call node .\src\import-from-excel.js "%EXCEL%" %REPLACE% || goto :fail

echo.
echo ✅ Готово! Дубликаты по (name,lat,lon) игнорируются.
echo.
pause
exit /b 0

:fail
echo [ОШИБКА] Импорт завершился с ошибкой.
pause
exit /b 1

