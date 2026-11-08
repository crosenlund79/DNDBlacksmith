@echo off
REM Runs the automated tests headless. Usage: run_tests_windows.bat [smoke|full]   Exit code 0 = all passed.
REM full: compile check + regression & progression suite + unit tests; smoke: compile check + fast suite subset.
REM Reports: %APPDATA%\Godot\app_userdata\Ember & Ash\logs\  (suite_report.txt, test_report.txt). Real saves are never touched.
setlocal
set "PROJ=%~dp0"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=full"
if not defined GODOT for %%f in ("%PROJ%Godot_v4*.exe") do set "GODOT=%%~f"
if not defined GODOT set "GODOT=godot"
if not exist "%PROJ%.godot\imported" "%GODOT%" --headless --path "%PROJ%" --import
set FAIL=0
"%GODOT%" --headless --path "%PROJ%" res://tests/compile_all.tscn || set FAIL=1
"%GODOT%" --headless --path "%PROJ%" res://tests/suite/suite.tscn -- %MODE% || set FAIL=1
if "%MODE%"=="full" "%GODOT%" --headless --path "%PROJ%" res://tests/test_runner.tscn || set FAIL=1
echo Exit code: %FAIL%
endlocal & exit /b %FAIL%
