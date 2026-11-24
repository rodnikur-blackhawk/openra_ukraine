@echo off
rem Starts OpenRA with the "Red Alert: Ukraine" mod (mods\ra-ukraine).
cd /d "%~dp0"
if not exist "mods\ra-ukraine\mod.yaml" (
    echo The mod folder mods\ra-ukraine was not found next to RedAlert.exe.
    echo Extract the mod archive into the OpenRA folder and try again.
    pause
    exit /b 1
)
start "" "%~dp0RedAlert.exe" Game.Mod=ra-ukraine
