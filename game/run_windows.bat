@echo off
REM Ember ^& Ash - Windows launcher
REM Set the GODOT variable to your Godot 4.3+ executable, or put Godot_v4*.exe next to this file.
setlocal
set "PROJ=%~dp0"
if not defined GODOT for %%f in ("%PROJ%Godot_v4*.exe") do set "GODOT=%%~f"
if not defined GODOT set "GODOT=godot"
if not exist "%PROJ%.godot\imported" (
  echo First run: importing art, audio and fonts - this takes a minute...
  "%GODOT%" --headless --path "%PROJ%" --import
)
"%GODOT%" --path "%PROJ%" %*
endlocal
