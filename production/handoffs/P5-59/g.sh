#!/bin/bash
# godot wrapper: isolated APPDATA, dummy audio
export APPDATA=/tmp/p559/appdata
mkdir -p $APPDATA
exec "C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" --audio-driver Dummy "$@"
