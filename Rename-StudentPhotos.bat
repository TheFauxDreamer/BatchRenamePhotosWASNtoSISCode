@echo off
setlocal

rem ==========================================================================
rem  Student Photo Renamer - batch launcher
rem  Keep this .bat, Rename-StudentPhotos.ps1, the mapping CSV, and the photos
rem  all in the SAME folder. Then just double-click this file.
rem ==========================================================================

set "SCRIPT=%~dp0Rename-StudentPhotos.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: Cannot find Rename-StudentPhotos.ps1 next to this batch file.
    echo Make sure both files are saved in the same folder.
    echo.
    pause
    exit /b 1
)

echo ============================================================
echo   Student Photo Renamer
echo ============================================================
echo.
echo Folder: %~dp0
echo.
echo ---------- PREVIEW (dry run - nothing will change) ----------
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -DryRun

echo.
set "CONFIRM="
set /p "CONFIRM=Proceed with the actual rename? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo Cancelled. No files were changed.
    echo.
    pause
    exit /b 0
)

echo.
echo ---------- RENAMING ----------
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo Done.
echo.
pause
endlocal
