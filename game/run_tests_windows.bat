@echo off
REM Runs the baseline automated tests headless. Exit code 0 = all passed.
setlocal
set "PROJ=%~dp0"
if not defined GODOT for %%f in ("%PROJ%Godot_v4*.exe") do set "GODOT=%%~f"
if not defined GODOT set "GODOT=godot"
if not exist "%PROJ%.godot\imported" "%GODOT%" --headless --path "%PROJ%" --import
"%GODOT%" --headless --path "%PROJ%" res://tests/test_runner.tscn
echo Exit code: %ERRORLEVEL%  (report: %%APPDATA%%\Godot\app_userdata\Ember ^& Ash\logs\test_report.txt)
endlocal
