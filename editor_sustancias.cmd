@echo off
rem Abre el diseñador de sustancias de Yonkiland (aparte del juego): precios y efectos en tablas.
rem Los retoques se guardan en game\data\equilibrio.json y mandan sobre game\scripts\defs.gd.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://editor/editor_sustancias.tscn
