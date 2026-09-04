@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ==========================
REM 1. Resolve config file name (customizable)
REM ==========================
if "%~1"=="" (
    set CONFIG_FILE=config.json
) else (
    set CONFIG_FILE=%~1
)

REM Directory of this script
set SCRIPT_DIR=%~dp0

echo Using config file: %CONFIG_FILE%
echo Script directory: %SCRIPT_DIR%
echo.

REM ==========================
REM 2. If config does not exist, create a template and exit
REM ==========================
if not exist "%SCRIPT_DIR%%CONFIG_FILE%" (
    echo [INFO] Config file not found, generating template: %SCRIPT_DIR%%CONFIG_FILE%
    > "%SCRIPT_DIR%%CONFIG_FILE%" echo {
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   "adbPath": "adb",
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   "packageName": "com.ns.service",
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   "targetDir": "/storage/emulated/0/Android/data/com.ns.service/files",
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   "outputFileName": "game.obb",
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   "pckSources": [
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo     {
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo       "pckPath": "E:/project/build/output/data/game.pck"
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo     }
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo   ]
    >>"%SCRIPT_DIR%%CONFIG_FILE%" echo }

    echo [INFO] Template created. Please edit ^"%SCRIPT_DIR%%CONFIG_FILE%^" and run this script again.
    pause
    goto :EOF
)

REM ==========================
REM 3. Parse JSON config
REM ==========================
pushd "%SCRIPT_DIR%"

echo Reading config file: %CONFIG_FILE%
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "try { $cfg = Get-Content -Raw -Encoding UTF8 '%CONFIG_FILE%' | ConvertFrom-Json; Write-Output ('ADB=' + $cfg.adbPath); Write-Output ('TARGETDIR=' + $cfg.targetDir); Write-Output ('OUTPUTNAME=' + $cfg.outputFileName); $index = 0; foreach ($item in $cfg.pckSources) { Write-Output ('SRC' + $index + '_PATH=' + $item.pckPath); $index++; } Write-Output ('COUNT=' + $index); } catch { Write-Error $_.Exception.Message; exit 1 }"`) do (
    for /f "tokens=1,2 delims==" %%A in ("%%I") do (
        set %%A=%%B
    )
)

if errorlevel 1 (
    echo [ERROR] Failed to parse JSON config.
    popd
    goto :EOF
)

if "%ADB%"=="" (
    set ADB=adb
)

echo ADB path: %ADB%
echo Target directory: %TARGETDIR%
echo Output file name: %OUTPUTNAME%
echo Item count: %COUNT%
echo.

REM ==========================
REM 4. Check adb
REM ==========================
"%ADB%" version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb is not available. Please check adbPath or your PATH environment.
    popd
    goto :EOF
)

REM ==========================
REM 5. Process each PCK entry and push
REM ==========================
set /a IDX=0
:LOOP_SOURCES
if %IDX% GEQ %COUNT% goto DONE_SOURCES

call set PCKPATH=%%SRC%IDX%_PATH%%

echo Processing item %IDX%:
echo  PCK path: %PCKPATH%

REM PCKPATH is expected to be an absolute path; normalize slashes
set ABS_PCK=%PCKPATH%
set ABS_PCK=%ABS_PCK:/=\%

if not exist "%ABS_PCK%" (
    echo  [WARN] PCK file not found: %ABS_PCK%
    set /a IDX+=1
    echo.
    goto LOOP_SOURCES
)

REM Temporary directory under current script directory
set TMP_DIR=%SCRIPT_DIR%temp_obb_%IDX%
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

set OBB_PATH=%TMP_DIR%\%OUTPUTNAME%

echo  Copying "%ABS_PCK%" to "%OBB_PATH%"
copy /Y "%ABS_PCK%" "%OBB_PATH%" >nul
if errorlevel 1 (
    echo  [ERROR] Copy failed.
    set /a IDX+=1
    echo.
    goto LOOP_SOURCES
)

echo  Pushing with adb to %TARGETDIR%
"%ADB%" push "%OBB_PATH%" "%TARGETDIR%/%OUTPUTNAME%"
if errorlevel 1 (
    echo  [ERROR] adb push failed.
) else (
    echo  [OK] adb push succeeded.
)

REM Clean up temp directory
rd /S /Q "%TMP_DIR%" >nul 2>&1

set /a IDX+=1
echo.
goto LOOP_SOURCES

:DONE_SOURCES
echo All items processed.
popd
endlocal
pause