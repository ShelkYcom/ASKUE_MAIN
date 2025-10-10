@echo on
setlocal ENABLEDELAYEDEXPANSION

REM ===== SETTINGS =====
set "DB=.\app.sqlite"
set "INPUT=ais.csv"                REM Rename your report to ais.csv (CSV with ; separator)
set "TMP=%~dp0tmp_ais"
set "CSV_NOHEADER=%TMP%\_noheader.csv"

if not exist "%TMP%" mkdir "%TMP%"

set "BASE=%~dp0"
set "BASE_UNIX=%BASE:\=/%"
set "SQL_SETUP=%BASE_UNIX%setup_ais.sql"
set "SQL_ADDON=%BASE_UNIX%setup_ais_points_addon.sql"

if not exist "%BASE%setup_ais.sql" (
  echo [ERROR] setup_ais.sql not found in %BASE%
  pause
  exit /b 1
)
if not exist "%BASE%setup_ais_points_addon.sql" (
  echo [ERROR] setup_ais_points_addon.sql not found in %BASE%
  pause
  exit /b 1
)

echo Using SQL files:
echo   %SQL_SETUP%
echo   %SQL_ADDON%

echo Checking input CSV: %INPUT%
if not exist "%INPUT%" (
  echo [ERROR] Input "ais.csv" not found. Export your report as CSV and rename it to ais.csv.
  pause
  exit /b 1
)

REM ===== STRIP FIRST 7 HEADER ROWS =====
echo Stripping first 7 header rows with PowerShell...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$in='%INPUT%'; $out='%CSV_NOHEADER%'; Get-Content -LiteralPath $in | Select-Object -Skip 7 | Set-Content -LiteralPath $out -Encoding UTF8"
if errorlevel 1 (
  echo [ERROR] Failed to strip header via PowerShell.
  pause
  exit /b 1
)

REM ===== SQLITE PATH FIX (use forward slashes to avoid \t escapes) =====
set "CSV_IMPORT=%CSV_NOHEADER:\=/%"
echo Will import from: %CSV_IMPORT%

REM ===== SQLITE IMPORT =====
where sqlite3 >nul 2>&1
if errorlevel 1 (
  if exist "%~dp0sqlite3.exe" (
    set "SQLITE=%~dp0sqlite3.exe"
  ) else (
    echo [ERROR] sqlite3.exe not found. Put sqlite3.exe next to this .bat or in PATH.
    pause
    exit /b 1
  )
) else (
  for /f "usebackq tokens=*" %%A in (`where sqlite3`) do set "SQLITE=%%A"
)

echo Importing into %DB% using %SQLITE% ...
"%SQLITE%" "%DB%" ^
  ".timeout 4000" ^
  "PRAGMA journal_mode=WAL;" ^
  "DROP TABLE IF EXISTS __stage22;" ^
  "CREATE TABLE __stage22(c1 TEXT,c2 TEXT,c3 TEXT,c4 TEXT,c5 TEXT,c6 TEXT,c7 TEXT,c8 TEXT,c9 TEXT,c10 TEXT,c11 TEXT,c12 TEXT,c13 TEXT,c14 TEXT,c15 TEXT,c16 TEXT,c17 TEXT,c18 TEXT,c19 TEXT,c20 TEXT,c21 TEXT,c22 TEXT);" ^
  ".mode csv" ^
  ".separator ;" ^
  ".import --skip 1 \"%CSV_IMPORT%\" __stage22" ^
  "CREATE TABLE IF NOT EXISTS ais_raw (A TEXT,B TEXT,D TEXT,E TEXT,F TEXT,H TEXT, imported_at TEXT DEFAULT (datetime('now')));" ^
  "INSERT INTO ais_raw(A,B,D,E,F,H) SELECT c1,c2,c4,c5,c6,c8 FROM __stage22;" ^
  "DROP TABLE __stage22;" ^
  ".read \"%BASE_UNIX%setup_ais_compat.sql\"" ^
  ".read \"%SQL_ADDON%\""
  ".read "%BASE_UNIX%update_points_status_2d.sql""


if errorlevel 1 (
  echo [ERROR] SQLite import failed.
  pause
  exit /b 1
)

echo [OK] Import done. DB: %DB%
pause
exit /b 0
