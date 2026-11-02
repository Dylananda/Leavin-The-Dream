@echo off
rem Abre el diseñador de personajes de Yonkiland (aparte del juego).
rem Los personajes se guardan en game\data\personajes\ y el juego los saca a la calle.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://editor/editor_personajes.tscn
