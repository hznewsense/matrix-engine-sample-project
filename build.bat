@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM MESample Build Script
REM ============================================================

REM ---------- ANSI Colors ----------
for /F "delims=" %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"
set "COLOR_RESET=%ESC%[0m"
set "COLOR_RED=%ESC%[91m"
set "COLOR_YELLOW=%ESC%[93m"
set "COLOR_GREEN=%ESC%[92m"
set "COLOR_CYAN=%ESC%[96m"

REM ---------- Configuration ----------
set NDK_VERSION=28.1.13356709
set ANDROID_ABI=arm64-v8a
set SCONS_ARCH=arm64
set SCONS_TARGET=template_release
set EXPORT_PRESET=Android
set LOCAL_GRADLE_CMD=

REM ---------- Path Configuration ----------
set REPO_ROOT=%~dp0
if "%REPO_ROOT:~-1%"=="\" set REPO_ROOT=%REPO_ROOT:~0,-1%

for /f "delims=" %%E in ('dir /b /s "%REPO_ROOT%\MatrixEngine\*.exe" 2^>nul') do if not defined MATRIX_EDITOR set "MATRIX_EDITOR=%%E"
set MATRIX_PROJECT_DIR=%REPO_ROOT%\MESample
set MATRIX_SOURCE_DIR=%MATRIX_PROJECT_DIR%\Source
set MATRIX_BUILD_DIR=%MATRIX_PROJECT_DIR%\bin
set PCK_DIR=%MATRIX_PROJECT_DIR%\Pck
set PCK_OUT=%PCK_DIR%\game.pck
set SO_OUT=%MATRIX_BUILD_DIR%\libMESample.android.template_release.arm64.so

set ANDROID_PROJECT_ROOT=%REPO_ROOT%\MESampleJava\MatrixRenderAsService
set RENDER_SERVICE_DIR=%ANDROID_PROJECT_ROOT%\MatrixRenderService
set HMI_DIR=%ANDROID_PROJECT_ROOT%\MatrixHMI
set SR_DIR=%ANDROID_PROJECT_ROOT%\MatrixSR
set AAR_PROJECT_ROOT=%REPO_ROOT%\MESampleJava\MatrixRenderAsAAR
set AAR_APP_DIR=%AAR_PROJECT_ROOT%\app
set AAR_MERGE_DIR=%AAR_PROJECT_ROOT%\merge
set AAR_MERGE_JNILIBS_DIR=%AAR_MERGE_DIR%\jniLibs\%ANDROID_ABI%
set AAR_JNILIBS_DIR=%AAR_APP_DIR%\jniLibs\%ANDROID_ABI%
REM merge 输出 AAR：按新命名规范 MatrixSdk_Integrated_<version>_<timestamp>.aar 输出到 app/libs，并清理旧 AAR（保证 gradle 只看到一个，避免重复类）
set MATRIX_SDK_VERSION=1.3.0
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"`) do set "BUILD_TIMESTAMP=%%T"
set "AAR_OUTPUT=%AAR_APP_DIR%\libs\MatrixSdk_Integrated_%MATRIX_SDK_VERSION%_%BUILD_TIMESTAMP%.aar"

set SERVICE_ASSETS_DIR=%RENDER_SERVICE_DIR%\src\main\assets
set SERVICE_JNILIBS_DIR=%RENDER_SERVICE_DIR%\jniLibs\%ANDROID_ABI%
set AAR_ASSETS_DIR=%AAR_APP_DIR%\src\main\assets

set APKS_DIR=%REPO_ROOT%\Apks
set LOG_DIR=%REPO_ROOT%\.build-logs
set USER_ENV_FILE=%REPO_ROOT%\.setup-user-env.cmd

if exist "%USER_ENV_FILE%" call "%USER_ENV_FILE%"

if /I "%~1"=="--internal-build-gradle-project" (
    shift
    goto build_gradle_project
)
if /I "%~1"=="--internal-resolve-android-sdk" (
    shift
    goto resolve_android_sdk
)
if /I "%~1"=="--internal-resolve-android-ndk" (
    shift
    goto resolve_android_ndk
)

goto main

REM ---------- Command Line Switches ----------
:parse_args
if "%~1"=="" goto args_done
set "ARG_HANDLED=0"
if /I "%~1"=="--skip-so" set BUILD_SO=0
if /I "%~1"=="--skip-so" set "ARG_HANDLED=1"
if /I "%~1"=="--skip-pck" set BUILD_PCK=0
if /I "%~1"=="--skip-pck" set "ARG_HANDLED=1"
if /I "%~1"=="--skip-copy" set BUILD_COPY=0
if /I "%~1"=="--skip-copy" set "ARG_HANDLED=1"
if /I "%~1"=="--skip-apk-service" set BUILD_APK_SERVICE=0
if /I "%~1"=="--skip-apk-service" set "ARG_HANDLED=1"
if /I "%~1"=="--skip-apk-lib" set BUILD_APK_LIB=0
if /I "%~1"=="--skip-apk-lib" set "ARG_HANDLED=1"
if /I "%~1"=="--skip-apk" set BUILD_APK_SERVICE=0
if /I "%~1"=="--skip-apk" set "ARG_HANDLED=1"
if /I "%~1"=="--clean-apks" set CLEAN_APKS=1
if /I "%~1"=="--clean-apks" set "ARG_HANDLED=1"
if /I "%~1"=="--release" (
    set APK_BUILD_TYPE=Release
    set APK_VARIANT_DIR=release
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--clean-pck" (
    set CLEAN_PCK=1
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--so" (
    set BUILD_SO=1
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--only-so" (
    set BUILD_SO=1
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--pck" (
    set BUILD_SO=0
    set BUILD_PCK=1
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--only-pck" (
    set BUILD_SO=0
    set BUILD_PCK=1
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--apk-service" (
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=1
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--only-apk-lib" (
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=1
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--only-apk-service" (
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=1
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--apk-lib" (
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=0
    set BUILD_APK_LIB=1
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--only-apk" (
    set BUILD_SO=0
    set BUILD_PCK=0
    set BUILD_COPY=0
    set BUILD_APK_SERVICE=1
    set BUILD_APK_LIB=0
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--all" (
    set BUILD_SO=1
    set BUILD_PCK=1
    set BUILD_COPY=1
    set BUILD_APK_SERVICE=1
    set BUILD_APK_LIB=1
    set CLEAN_APKS=1
    set "ARG_HANDLED=1"
)
if /I "%~1"=="--help" goto usage
if /I "%~1"=="--help" set "ARG_HANDLED=1"
if "%ARG_HANDLED%"=="0" (
    call :log_error "Unknown option: %~1"
    echo.
    echo Run `build.bat --help` to see available options.
    exit /b 1
)
shift
goto parse_args

:args_done
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul

call :print_header

if "%CLEAN_PCK%"=="1" (
    call :clean_pck
)

if "%CLEAN_APKS%"=="1" (
    call :clean_apks
)

if "%BUILD_SO%"=="0" if "%BUILD_PCK%"=="0" if "%BUILD_COPY%"=="0" if "%BUILD_APK_SERVICE%"=="0" if "%BUILD_APK_LIB%"=="0" goto build_done

call :detect_tools
if errorlevel 1 goto failed

call :validate_layout
if errorlevel 1 goto failed

if "%BUILD_SO%"=="1" (
    call :build_android_so
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping so build (--skip-so)."
)

if "%BUILD_PCK%"=="1" (
    call :export_pck
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping pck export (--skip-pck)."
)

if "%BUILD_COPY%"=="1" (
    call :copy_to_android_project
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping copy to Android project (--skip-copy)."
)

if not defined APK_META_INITED if "%BUILD_APK_SERVICE%"=="1" (
    set "APK_META_INITED=1"
    call :init_apk_naming_meta
)
if not defined APK_META_INITED if "%BUILD_APK_LIB%"=="1" (
    set "APK_META_INITED=1"
    call :init_apk_naming_meta
)

if "%BUILD_APK_SERVICE%"=="1" (
    call :build_android_service_apks
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping apk-service build."
)

if "%BUILD_APK_LIB%"=="1" (
    call :build_android_lib_apk
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping apk-lib build."
)

echo.
call :echo_color "%COLOR_GREEN%" "[ OK ] Build complete."
echo.
echo Output files:
if "%BUILD_PCK%"=="1" echo   PCK: %PCK_OUT%
if "%BUILD_SO%"=="1" echo   SO : %SO_OUT%
if "%BUILD_APK_SERVICE%"=="1" echo   APK-SERVICE: %APKS_DIR%
if "%BUILD_APK_LIB%"=="1" echo   APK-LIB    : %APKS_DIR%\MatrixUsedAsLib.apk
echo.
goto build_done

:usage
echo.
echo Usage:
echo   build.bat [options]
echo.
echo Options:
echo   --so            Only build Android so
echo   --pck           Only export game.pck
echo   --apk-service   Only build MatrixRenderAsService APKs
echo   --apk-lib       Only Build MatrixRenderAsAAR APK
echo   --release       Build MatrixUsedAsLib.apk in release (R8 shrink + debug-keystore sign)
echo   --skip-so       Skip Android so build
echo   --skip-pck      Skip game.pck export
echo   --skip-copy     Skip copy to Android project
echo   --skip-apk-service  Skip MatrixRenderAsService APK build
echo   --skip-apk-lib      Skip MatrixRenderAsAAR APK build
echo   --clean-apks    Clean APKs directory before build
echo   --clean-pck     Delete MESample/Pck/game.pck before build
echo   --all           Full clean build (clean + build all)
echo   --help          Show help
echo.
echo Examples:
echo   build.bat                 - Full build
echo   build.bat --so            - Only build Android so
echo   build.bat --pck           - Only export game.pck
echo   build.bat --skip-apk-service - Build so and pck, skip service APKs
echo   build.bat --apk-service   - Only build MatrixRenderAsService APKs
echo   build.bat --apk-lib       - Build MatrixRenderAsAAR APK
echo   build.bat --clean-apks    - Clean APKs directory before build
echo   build.bat --clean-pck     - Delete game.pck only
echo   build.bat --all           - Clean and build everything
echo.
goto build_done

:build_done
goto finish_success

:print_header
echo ============================================================
echo MESample Build Script
echo ============================================================
echo Repository Root : %REPO_ROOT%
echo Matrix Editor   : %MATRIX_EDITOR%
echo Matrix Project  : %MATRIX_PROJECT_DIR%
echo Android Root    : %ANDROID_PROJECT_ROOT%
echo APKs Output     : %APKS_DIR%
echo ============================================================
echo.
exit /b 0

:detect_tools
call :log_info "Detecting build tools..."

set "PYTHON_CMD="
if "%BUILD_SO%"=="1" (
    call :probe_python "py -3"
    if not errorlevel 1 set "PYTHON_CMD=py -3"
    if "!PYTHON_CMD!"=="" (
        call :probe_python "python"
        if not errorlevel 1 set "PYTHON_CMD=python"
    )

    if "!PYTHON_CMD!"=="" (
        call :log_error "Python not found or unusable. Please run setup.bat first."
        exit /b 1
    )
    call :log_ok "Python command: !PYTHON_CMD!"
)

if "%BUILD_SO%"=="1" (
    call :resolve_android_sdk
    if errorlevel 1 (
        call :log_error "Android SDK not found. Please run setup.bat first."
        exit /b 1
    )

    call :resolve_android_ndk
    if errorlevel 1 (
        call :log_error "Android NDK %NDK_VERSION% not found. Please run setup.bat first."
        exit /b 1
    )

    if defined SCONS_CMD (
        call :log_info "Using saved SCons command: !SCONS_CMD!"
    ) else (
        set "SCONS_CMD="
        for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$cmd = Get-Command scons -ErrorAction SilentlyContinue; if ($cmd) { $cmd.Source }"`) do (
            set "SCONS_CMD=%%S"
        )
        if defined SCONS_CMD (
            call :log_info "Using SCons command: !SCONS_CMD!"
        ) else (
            where scons >nul 2>nul
            if %ERRORLEVEL%==0 (
                set "SCONS_CMD=scons"
                call :log_ok "SCons found in PATH"
            ) else (
                !PYTHON_CMD! -m SCons --version >nul 2>nul
                if %ERRORLEVEL%==0 (
                    set "SCONS_CMD=!PYTHON_CMD! -m SCons"
                    call :log_info "SCons not in PATH, using: !SCONS_CMD!"
                ) else (
                    call :log_error "SCons not found. Install via: pip install scons"
                    exit /b 1
                )
            )
        )
    )
)

if "%BUILD_APK_SERVICE%"=="1" (
    call :resolve_android_sdk
    if errorlevel 1 (
        call :log_error "Android SDK not found. Please run setup.bat first."
        exit /b 1
    )
)

if "%BUILD_APK_LIB%"=="1" (
    call :resolve_android_sdk
    if errorlevel 1 (
        call :log_error "Android SDK not found. Please run setup.bat first."
        exit /b 1
    )
)

if "%BUILD_PCK%"=="1" (
    if not exist "%MATRIX_EDITOR%" (
        call :log_error "Matrix Editor not found: %MATRIX_EDITOR%"
        exit /b 1
    )
    call :log_ok "Matrix Editor found"
)

if "%BUILD_APK_SERVICE%"=="1" (
    call :prepare_java_for_gradle
    if errorlevel 1 (
        call :log_error "JDK 17+ not found. Please run setup.bat first."
        exit /b 1
    )
)

if "%BUILD_APK_LIB%"=="1" (
    call :prepare_java_for_gradle
    if errorlevel 1 (
        call :log_error "JDK 17+ not found. Please run setup.bat first."
        exit /b 1
    )
)

call :print_dependency_summary
exit /b 0

:probe_python
%~1 --version >nul 2>nul
exit /b %ERRORLEVEL%

:print_dependency_summary
echo.
call :log_info "Build dependencies:"
if defined PYTHON_CMD echo   Python            = !PYTHON_CMD!
if defined SCONS_CMD echo   SCons             = !SCONS_CMD!
if defined ANDROID_SDK_ROOT echo   Android SDK       = !ANDROID_SDK_ROOT!
if defined ANDROID_NDK_ROOT echo   Android NDK       = !ANDROID_NDK_ROOT!
if defined JAVA_HOME echo   JDK               = !JAVA_HOME!

set "SUMMARY_GRADLE_RUNNER="
if "%BUILD_APK_SERVICE%"=="1" call :resolve_preferred_gradle_runner "%ANDROID_PROJECT_ROOT%" SUMMARY_GRADLE_RUNNER
if not defined SUMMARY_GRADLE_RUNNER if "%BUILD_APK_LIB%"=="1" call :resolve_preferred_gradle_runner "%AAR_PROJECT_ROOT%" SUMMARY_GRADLE_RUNNER
if defined SUMMARY_GRADLE_RUNNER echo   Gradle            = !SUMMARY_GRADLE_RUNNER!
echo.
exit /b 0

:validate_layout
call :log_info "Validating project layout..."

if not exist "%MATRIX_PROJECT_DIR%\project.godot" (
    call :log_error "Matrix project not found: %MATRIX_PROJECT_DIR%"
    exit /b 1
)

if "%BUILD_SO%"=="1" if not exist "%MATRIX_SOURCE_DIR%\SConstruct" (
    call :log_error "SConstruct not found: %MATRIX_SOURCE_DIR%"
    exit /b 1
)

if "%BUILD_COPY%"=="1" if not exist "%ANDROID_PROJECT_ROOT%" (
    call :log_error "Android project not found: %ANDROID_PROJECT_ROOT%"
    exit /b 1
)

if "%BUILD_APK_SERVICE%"=="1" if not exist "%ANDROID_PROJECT_ROOT%" (
    call :log_error "Android project not found: %ANDROID_PROJECT_ROOT%"
    exit /b 1
)

if "%BUILD_APK_LIB%"=="1" if not exist "%AAR_PROJECT_ROOT%" (
    call :log_error "Android project not found: %AAR_PROJECT_ROOT%"
    exit /b 1
)

call :log_ok "Project layout validated"
exit /b 0

:clean_pck
call :log_info "Cleaning game.pck..."
if exist "%PCK_OUT%" (
    del /q "%PCK_OUT%" >nul 2>nul
    if exist "%PCK_OUT%" (
        call :log_error "Failed to delete game.pck: %PCK_OUT%"
        exit /b 1
    )
    call :log_ok "Deleted: %PCK_OUT%"
    exit /b 0
)
call :log_warn "game.pck not found, nothing to clean."
exit /b 0

:clean_apks
call :log_info "Cleaning APKs directory..."
if exist "%APKS_DIR%" (
    rd /s /q "%APKS_DIR%" 2>nul
)
mkdir "%APKS_DIR%" >nul 2>nul
call :log_ok "APKs directory cleaned"
exit /b 0

:build_android_so
call :log_info "Building Android so..."
pushd "%MATRIX_SOURCE_DIR%"

if exist "%SO_OUT%" (
    call :log_info "Existing so found, checking for updates."
)

call :log_info "SCons output will be streamed below."

REM Fix: Scoop may save SCons as a PowerShell shim (*.ps1).
REM Running *.ps1 directly from cmd/bat is unreliable, so prefer Python module invocation.
set "SCONS_RUNNER=%SCONS_CMD%"
if /I "!SCONS_RUNNER:~-4!"==".ps1" (
    call :log_warn "SCONS_CMD points to a PowerShell shim, using Python module invocation instead."
    set "SCONS_RUNNER=!PYTHON_CMD! -m SCons"
)

call :log_info "SCons command: !SCONS_RUNNER! platform=android target=%SCONS_TARGET% arch=%SCONS_ARCH%"
cmd /d /c "set \"ANDROID_HOME=%ANDROID_HOME%\" & set \"ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%\" & set \"ANDROID_NDK_ROOT=%ANDROID_NDK_ROOT%\" & !SCONS_RUNNER! platform=android target=%SCONS_TARGET% arch=%SCONS_ARCH%"
set "SCONS_RESULT=%ERRORLEVEL%"
popd

if not "%SCONS_RESULT%"=="0" (
    call :log_error "Android so build failed."
    exit /b 1
)

if not exist "%SO_OUT%" (
    call :log_warn "Expected so path not found, searching generated libMESample*.so under project..."
    set "FOUND_SO="
    for /r "%MATRIX_PROJECT_DIR%" %%F in (libMESample*.so) do (
        if not defined FOUND_SO set "FOUND_SO=%%F"
    )

    if defined FOUND_SO (
        if not exist "%MATRIX_BUILD_DIR%" mkdir "%MATRIX_BUILD_DIR%" >nul 2>nul
        copy /Y "!FOUND_SO!" "%SO_OUT%" >nul
        if not errorlevel 1 (
            call :log_warn "Copied generated so from: !FOUND_SO!"
        )
    )
)

if not exist "%SO_OUT%" (
    call :log_error "Build complete but so not found: %SO_OUT%"
    call :log_error "Please run: dir /s /b libMESample*.so"
    exit /b 1
)

for %%A in ("%SO_OUT%") do set "SO_SIZE=%%~zA"
call :log_ok "Android so built: %SO_OUT% (%SO_SIZE% bytes)"
exit /b 0

:export_pck
call :log_info "Exporting game.pck..."

if not exist "%PCK_DIR%" mkdir "%PCK_DIR%" >nul 2>nul

pushd "%MATRIX_SOURCE_DIR%"
set "PCK_RESULT=1"
call :log_info "Matrix export output will be streamed below."
"%MATRIX_EDITOR%" --path "%MATRIX_PROJECT_DIR%" --headless --export-pack "%EXPORT_PRESET%" "%PCK_OUT%"
set "PCK_RESULT=%ERRORLEVEL%"
popd

if not "%PCK_RESULT%"=="0" (
    call :log_error "game.pck export failed with exit code %PCK_RESULT%"
    exit /b 1
)

if not exist "%PCK_OUT%" (
    call :log_error "Export complete but pck not found: %PCK_OUT%"
    exit /b 1
)

for %%A in ("%PCK_OUT%") do set "PCK_SIZE=%%~zA"
call :log_ok "game.pck exported: %PCK_OUT% (%PCK_SIZE% bytes)"
exit /b 0

:copy_to_android_project
call :log_info "Copying files to Android project..."

if not exist "%PCK_OUT%" (
    call :log_error "pck not found: %PCK_OUT%"
    exit /b 1
)

if not exist "%SO_OUT%" (
    call :log_error "so not found: %SO_OUT%"
    exit /b 1
)

if not exist "%SERVICE_ASSETS_DIR%" mkdir "%SERVICE_ASSETS_DIR%" >nul 2>nul
if not exist "%SERVICE_JNILIBS_DIR%" mkdir "%SERVICE_JNILIBS_DIR%" >nul 2>nul

copy /Y "%PCK_OUT%" "%SERVICE_ASSETS_DIR%\game.pck" >nul
if not %ERRORLEVEL%==0 (
    call :log_error "Failed to copy game.pck."
    exit /b 1
)

copy /Y "%SO_OUT%" "%SERVICE_JNILIBS_DIR%\libMESample.android.template_release.arm64.so" >nul
if not %ERRORLEVEL%==0 (
    call :log_error "Failed to copy so."
    exit /b 1
)

call :log_ok "Files copied to Android project"
exit /b 0

:build_android_service_apks
call :log_info "Building apk-service..."

if not exist "%APKS_DIR%" mkdir "%APKS_DIR%" >nul 2>nul

set "BUILT_APKS=0"
set "SERVICE_GRADLE_RUNNER="
call :find_local_gradle
if exist "%LOCAL_GRADLE_CMD%" (
    call :check_gradle_version "%LOCAL_GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_info "Using local Gradle 8.13: %LOCAL_GRADLE_CMD%"
        set "SERVICE_GRADLE_RUNNER=%LOCAL_GRADLE_CMD%"
    ) else (
        call :log_warn "Local Gradle is incompatible, ignoring: %LOCAL_GRADLE_CMD%"
    )
)
if not defined SERVICE_GRADLE_RUNNER (
call :find_gradle_cmd
if defined GRADLE_CMD (
    call :check_gradle_version "%GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_info "Using Gradle from PATH: %GRADLE_CMD%"
        set "SERVICE_GRADLE_RUNNER=%GRADLE_CMD%"
    ) else (
        call :log_warn "Gradle from PATH is incompatible, fallback to gradlew.bat: %GRADLE_CMD%"
    )
) else (
    call :log_info "Gradle not found in PATH, fallback to gradlew.bat."
)
)

if not defined SERVICE_GRADLE_RUNNER (
    if exist "%ANDROID_PROJECT_ROOT%\gradlew.bat" (
        set "SERVICE_GRADLE_RUNNER=gradlew.bat"
    ) else (
        call :log_error "No compatible Gradle runner found for MatrixRenderAsService."
        exit /b 1
    )
)

if not defined SERVICE_GRADLE_RUNNER (
    call :log_warn "MatrixRenderAsService gradlew.bat not found, skipping apk-service."
    exit /b 0
)

set "COMPONENT=RenderService"
set "LIBS_DIR=%RENDER_SERVICE_DIR%\libs"
set "APK_RES_FPS="
call :compose_apk_name
call "%~f0" --internal-build-gradle-project "%ANDROID_PROJECT_ROOT%" "MatrixRenderService" "!APK_NAME!" ":MatrixRenderService:assemble%APK_BUILD_TYPE%" "%RENDER_SERVICE_DIR%\build\outputs\apk\%APK_VARIANT_DIR%" "%SERVICE_GRADLE_RUNNER%"
if errorlevel 1 exit /b 1
set "BUILT_APKS=1"

set "COMPONENT=HMI"
set "LIBS_DIR=%HMI_DIR%\libs"
set "APK_RES_FPS=1920X1200_30fps"
call :compose_apk_name
call "%~f0" --internal-build-gradle-project "%ANDROID_PROJECT_ROOT%" "MatrixHMI" "!APK_NAME!" ":MatrixHMI:assemble%APK_BUILD_TYPE%" "%HMI_DIR%\build\outputs\apk\%APK_VARIANT_DIR%" "%SERVICE_GRADLE_RUNNER%"
if errorlevel 1 exit /b 1

set "COMPONENT=SR"
set "LIBS_DIR=%SR_DIR%\libs"
set "APK_RES_FPS=1920X1080_30fps"
call :compose_apk_name
call "%~f0" --internal-build-gradle-project "%ANDROID_PROJECT_ROOT%" "MatrixSR" "!APK_NAME!" ":MatrixSR:assemble%APK_BUILD_TYPE%" "%SR_DIR%\build\outputs\apk\%APK_VARIANT_DIR%" "%SERVICE_GRADLE_RUNNER%"
if errorlevel 1 exit /b 1

if "%BUILT_APKS%"=="0" (
    call :log_warn "No APKs were built. Check if gradle projects exist."
)

exit /b 0

:build_android_lib_apk
call :log_info "Building apk-lib..."

if not exist "%PCK_OUT%" (
    call :log_error "pck not found: %PCK_OUT%"
    exit /b 1
)

if not exist "%AAR_ASSETS_DIR%" mkdir "%AAR_ASSETS_DIR%" >nul 2>nul
if not exist "%AAR_MERGE_JNILIBS_DIR%" mkdir "%AAR_MERGE_JNILIBS_DIR%" >nul 2>nul
if not exist "%AAR_JNILIBS_DIR%" mkdir "%AAR_JNILIBS_DIR%" >nul 2>nul

copy /Y "%PCK_OUT%" "%AAR_ASSETS_DIR%\game.pck" >nul
if not %ERRORLEVEL%==0 (
    call :log_error "Failed to copy game.pck to MatrixRenderAsAAR."
    exit /b 1
)

if not exist "%SO_OUT%" (
    call :log_error "so not found: %SO_OUT%"
    exit /b 1
)

copy /Y "%SO_OUT%" "%AAR_MERGE_JNILIBS_DIR%\libMESample.android.template_release.arm64.so" >nul
if not %ERRORLEVEL%==0 (
    call :log_error "Failed to copy so to MatrixRenderAsAAR merge jniLibs."
    exit /b 1
)

copy /Y "%SO_OUT%" "%AAR_JNILIBS_DIR%\libMESample.android.template_release.arm64.so" >nul
if not %ERRORLEVEL%==0 (
    call :log_error "Failed to copy so to MatrixRenderAsAAR app jniLibs."
    exit /b 1
)

if not exist "%APKS_DIR%" mkdir "%APKS_DIR%" >nul 2>nul

pushd "%AAR_PROJECT_ROOT%"
REM 清理 app/libs 旧 AAR，保证 gradle 只看到一个（避免重复类）
if exist "%AAR_APP_DIR%\libs\*.aar" del /q "%AAR_APP_DIR%\libs\*.aar"
call :log_info "Packaging merged AAR..."
cmd /c .\merge.bat -o "!AAR_OUTPUT!"
set "MERGE_AAR_RESULT=%ERRORLEVEL%"
popd

if not "%MERGE_AAR_RESULT%"=="0" (
    call :log_error "merge.bat failed when packaging %AAR_OUTPUT%."
    exit /b 1
)

if not exist "%AAR_OUTPUT%" (
    call :log_error "AAR packaging complete but output not found: %AAR_OUTPUT%"
    exit /b 1
)

call :log_ok "AAR packaged: %AAR_OUTPUT%"

set "AAR_GRADLE_RUNNER="
call :find_local_gradle
if exist "%LOCAL_GRADLE_CMD%" (
    call :check_gradle_version "%LOCAL_GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_info "Using local Gradle 8.13: %LOCAL_GRADLE_CMD%"
        set "AAR_GRADLE_RUNNER=%LOCAL_GRADLE_CMD%"
    ) else (
        call :log_warn "Local Gradle is incompatible, ignoring: %LOCAL_GRADLE_CMD%"
    )
)
if not defined AAR_GRADLE_RUNNER (
call :find_gradle_cmd
if defined GRADLE_CMD (
    call :check_gradle_version "%GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_info "Using Gradle from PATH: %GRADLE_CMD%"
        set "AAR_GRADLE_RUNNER=%GRADLE_CMD%"
    ) else (
        call :log_warn "Gradle from PATH is incompatible, fallback to gradlew.bat: %GRADLE_CMD%"
    )
) else (
    call :log_info "Gradle not found in PATH, fallback to gradlew.bat."
)
)

if not defined AAR_GRADLE_RUNNER (
    if exist "%AAR_PROJECT_ROOT%\gradlew.bat" (
        set "AAR_GRADLE_RUNNER=gradlew.bat"
    ) else (
        call :log_error "No compatible Gradle runner found for MatrixRenderAsAAR."
        exit /b 1
    )
)

set "COMPONENT=UsedAsLib"
set "LIBS_DIR=%AAR_APP_DIR%\libs"
set "APK_RES_FPS=1920X1200_30fps"
call :compose_apk_name
call "%~f0" --internal-build-gradle-project "%AAR_PROJECT_ROOT%" "apk-lib" "!APK_NAME!" ":app:assemble%APK_BUILD_TYPE%" "%AAR_APP_DIR%\build\outputs\apk\%APK_VARIANT_DIR%" "%AAR_GRADLE_RUNNER%"
if errorlevel 1 exit /b 1

exit /b 0

:find_gradle_cmd
set "GRADLE_CMD="
where gradle >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%G in ('where gradle') do (
        if not defined GRADLE_CMD set "GRADLE_CMD=%%G"
    )
)
exit /b 0

:find_local_gradle
set "LOCAL_GRADLE_CMD="
set "GRADLE_HOME_CANDIDATE="
if defined GRADLE_HOME (
    set "GRADLE_HOME_CANDIDATE=%GRADLE_HOME:"=%"
    if exist "!GRADLE_HOME_CANDIDATE!\bin\gradle.bat" set "LOCAL_GRADLE_CMD=!GRADLE_HOME_CANDIDATE!\bin\gradle.bat"
)
if not defined LOCAL_GRADLE_CMD if exist "%~dp0.tools\gradle\gradle-8.13\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%~dp0.tools\gradle\gradle-8.13\bin\gradle.bat"
if not defined LOCAL_GRADLE_CMD call :scan_gradle_candidates "%USERPROFILE%"
if not defined LOCAL_GRADLE_CMD call :scan_gradle_candidates "%ProgramFiles%"
if not defined LOCAL_GRADLE_CMD call :scan_gradle_candidates "D:\Gradle"
if not defined LOCAL_GRADLE_CMD call :scan_gradle_candidates "E:\Gradle"
exit /b 0

:scan_gradle_candidates
if defined LOCAL_GRADLE_CMD exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

for /d %%D in ("%~1\gradle-%GRADLE_VERSION%") do (
    if not defined LOCAL_GRADLE_CMD if exist "%%~fD\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%%~fD\bin\gradle.bat"
)
for /d %%D in ("%~1\Gradle\gradle-%GRADLE_VERSION%") do (
    if not defined LOCAL_GRADLE_CMD if exist "%%~fD\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%%~fD\bin\gradle.bat"
)
for /d %%D in ("%~1\.gradle\gradle-%GRADLE_VERSION%") do (
    if not defined LOCAL_GRADLE_CMD if exist "%%~fD\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%%~fD\bin\gradle.bat"
)
exit /b 0

:check_gradle_version
set "GRADLE_VERSION_OK="
set "GRADLE_VERSION_OUTPUT="
set "EXPECTED_GRADLE_LINE=Gradle %GRADLE_VERSION%"
for /f "delims=" %%V in ('"%~1" --version 2^>^&1 ^| findstr /b /c:"Gradle "') do (
    if not defined GRADLE_VERSION_OUTPUT set "GRADLE_VERSION_OUTPUT=%%V"
)
if not defined GRADLE_VERSION_OUTPUT exit /b 0

if /I "!GRADLE_VERSION_OUTPUT!"=="!EXPECTED_GRADLE_LINE!" set "GRADLE_VERSION_OK=1"
exit /b 0

:resolve_preferred_gradle_runner
set "%~2="
call :find_local_gradle
if defined LOCAL_GRADLE_CMD (
    call :check_gradle_version "%LOCAL_GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        set "%~2=%LOCAL_GRADLE_CMD%"
        exit /b 0
    )
)

call :find_gradle_cmd
if defined GRADLE_CMD (
    call :check_gradle_version "%GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        set "%~2=%GRADLE_CMD%"
        exit /b 0
    )
)

if exist "%~1\gradlew.bat" (
    set "%~2=%~1\gradlew.bat"
    exit /b 0
)
exit /b 0

:resolve_android_sdk
set "SDK_CANDIDATE="

if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" set "SDK_CANDIDATE=%ANDROID_SDK_ROOT%"
if not defined SDK_CANDIDATE if defined ANDROID_HOME if exist "%ANDROID_HOME%" set "SDK_CANDIDATE=%ANDROID_HOME%"
if not defined SDK_CANDIDATE if exist "%LOCALAPPDATA%\Android\Sdk" set "SDK_CANDIDATE=%LOCALAPPDATA%\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "%USERPROFILE%\AppData\Local\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "%ProgramFiles%\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "%SystemDrive%\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "D:\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "D:\WorkTools\SDK"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "D:\SDK\Android"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "E:\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "E:\WorkTools\SDK"
if not defined SDK_CANDIDATE call :scan_sdk_candidate "E:\SDK\Android"

if not defined SDK_CANDIDATE exit /b 1

set "ANDROID_HOME=%SDK_CANDIDATE%"
set "ANDROID_SDK_ROOT=%SDK_CANDIDATE%"
call :log_info "Using Android SDK: %ANDROID_SDK_ROOT%"
exit /b 0

:scan_sdk_candidate
if defined SDK_CANDIDATE exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

if exist "%~1\platform-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\cmdline-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\build-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\platforms" set "SDK_CANDIDATE=%~1"
exit /b 0

:resolve_android_ndk
set "NDK_CANDIDATE="
set "NDK_CLANG="

if defined ANDROID_NDK_ROOT if exist "%ANDROID_NDK_ROOT%\source.properties" set "NDK_CANDIDATE=%ANDROID_NDK_ROOT%"
if not defined NDK_CANDIDATE if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%"
if not defined NDK_CANDIDATE if defined ANDROID_HOME if exist "%ANDROID_HOME%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_HOME%\ndk\%NDK_VERSION%"
if not defined NDK_CANDIDATE exit /b 1

set "NDK_CLANG=%NDK_CANDIDATE%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang++.exe"
if not exist "%NDK_CLANG%" exit /b 1

set "ANDROID_NDK_ROOT=%NDK_CANDIDATE%"
call :log_info "Using Android NDK: %ANDROID_NDK_ROOT%"
exit /b 0

:prepare_java_for_gradle
if defined JAVA_HOME (
    call :normalize_java_home "%JAVA_HOME%"
    if defined NORMALIZED_JAVA_HOME set "JAVA_HOME=%NORMALIZED_JAVA_HOME%"
)

if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" (
    call :check_java_version "%JAVA_HOME%\bin\java.exe"
    if "!JAVA_VERSION_OK!"=="1" exit /b 0
)

call :locate_java_home
if errorlevel 1 exit /b 1

set "JAVA_HOME=%JAVA_CANDIDATE%"
call :log_info "Using JAVA_HOME for Gradle: %JAVA_HOME%"
exit /b 0

:normalize_java_home
set "NORMALIZED_JAVA_HOME=%~1"
if not defined NORMALIZED_JAVA_HOME exit /b 0
for /f "tokens=* delims= " %%A in ("%NORMALIZED_JAVA_HOME%") do set "NORMALIZED_JAVA_HOME=%%A"
:normalize_java_home_trim
if defined NORMALIZED_JAVA_HOME if "%NORMALIZED_JAVA_HOME:~-1%"==" " set "NORMALIZED_JAVA_HOME=%NORMALIZED_JAVA_HOME:~0,-1%" & goto normalize_java_home_trim
if defined NORMALIZED_JAVA_HOME if "%NORMALIZED_JAVA_HOME:~-1%"=="\" set "NORMALIZED_JAVA_HOME=%NORMALIZED_JAVA_HOME:~0,-1%"
exit /b 0

:locate_java_home
set "JAVA_CANDIDATE="
set "JAVA_VERSION_OK="

if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" (
    call :check_java_version "%JAVA_HOME%\bin\java.exe"
    if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%JAVA_HOME%"
)
if not defined JAVA_CANDIDATE if exist "%ProgramFiles%\Microsoft" (
    for /d %%D in ("%ProgramFiles%\Microsoft\jdk-*") do (
        if not defined JAVA_CANDIDATE if exist "%%~fD\bin\java.exe" (
            call :check_java_version "%%~fD\bin\java.exe"
            if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD"
        )
    )
)
if not defined JAVA_CANDIDATE if exist "%ProgramFiles%\Eclipse Adoptium" (
    for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do (
        if not defined JAVA_CANDIDATE if exist "%%~fD\bin\java.exe" (
            call :check_java_version "%%~fD\bin\java.exe"
            if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD"
        )
    )
)
if not defined JAVA_CANDIDATE if exist "%ProgramFiles%\Java" (
    for /d %%D in ("%ProgramFiles%\Java\jdk-*") do (
        if not defined JAVA_CANDIDATE if exist "%%~fD\bin\java.exe" (
            call :check_java_version "%%~fD\bin\java.exe"
            if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD"
        )
    )
)
call :scan_java_candidates "%ProgramFiles%\Android"
call :scan_java_candidates "%ProgramFiles%"
call :scan_java_candidates "%LOCALAPPDATA%\Programs"
call :scan_jetbrains_jdks "%USERPROFILE%\.jdks"
if not defined JAVA_CANDIDATE (
    for /f "delims=" %%J in ('where java 2^>nul') do (
        if not defined JAVA_CANDIDATE if exist "%%~fJ" (
            call :check_java_version "%%~fJ"
            if "!JAVA_VERSION_OK!"=="1" (
                for %%K in ("%%~dpJ..") do set "JAVA_CANDIDATE=%%~fK"
            )
        )
    )
)

if not defined JAVA_CANDIDATE exit /b 1
exit /b 0

:scan_java_candidates
if defined JAVA_CANDIDATE exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

for /d %%D in ("%~1\Android Studio*") do (
    if not defined JAVA_CANDIDATE if exist "%%~fD\jbr\bin\java.exe" (
        call :check_java_version "%%~fD\jbr\bin\java.exe"
        if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD\jbr"
    )
    if not defined JAVA_CANDIDATE if exist "%%~fD\jre\bin\java.exe" (
        call :check_java_version "%%~fD\jre\bin\java.exe"
        if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD\jre"
    )
)
exit /b 0

:scan_jetbrains_jdks
if defined JAVA_CANDIDATE exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

for /d %%D in ("%~1\jbr-*") do (
    if not defined JAVA_CANDIDATE if exist "%%~fD\bin\java.exe" (
        call :check_java_version "%%~fD\bin\java.exe"
        if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD"
    )
)
for /d %%D in ("%~1\jdk-*") do (
    if not defined JAVA_CANDIDATE if exist "%%~fD\bin\java.exe" (
        call :check_java_version "%%~fD\bin\java.exe"
        if "!JAVA_VERSION_OK!"=="1" set "JAVA_CANDIDATE=%%~fD"
    )
)
exit /b 0

:check_java_version
set "JAVA_VERSION_OK="
set "JAVA_VERSION_OUTPUT="
for /f "delims=" %%V in ('"%~1" -version 2^>^&1') do (
    if not defined JAVA_VERSION_OUTPUT set "JAVA_VERSION_OUTPUT=%%V"
)
if not defined JAVA_VERSION_OUTPUT exit /b 0

echo(!JAVA_VERSION_OUTPUT!| findstr /r /c:"\"1[7-9]\." /c:"\"[2-9][0-9]\." >nul
if not errorlevel 1 set "JAVA_VERSION_OK=1"
exit /b 0

:build_gradle_project
set "GRADLE_DIR=%~1"
set "PROJECT_NAME=%~2"
set "APK_NAME=%~3"
set "GRADLE_TASK=%~4"
set "APK_SEARCH_ROOT=%~5"
set "GRADLE_RUNNER=%~6"
set "APK_SOURCE="
set "ORIGINAL_JAVA_HOME=%JAVA_HOME%"
set "ORIGINAL_PATH=%PATH%"

call :log_info "Building %PROJECT_NAME%..."

if not defined GRADLE_RUNNER (
    set "GRADLE_RUNNER=gradlew.bat"
)

if /I "%GRADLE_RUNNER%"=="gradlew.bat" (
    call :log_warn "Using Gradle wrapper for %PROJECT_NAME%. The first run may download Gradle %GRADLE_VERSION% and can appear idle for several minutes."
    call :log_info "Gradle wrapper output will be streamed below."
)

call :prepare_java_for_gradle
if errorlevel 1 (
    call :log_error "JDK 17+ not found. Please run setup.bat first."
    exit /b 1
)

set "PATH=%JAVA_HOME%\bin;%PATH%"

pushd "%GRADLE_DIR%"
call :sync_gradle_local_properties "%GRADLE_DIR%"
if errorlevel 1 (
    popd
    set "JAVA_HOME=%ORIGINAL_JAVA_HOME%"
    set "PATH=%ORIGINAL_PATH%"
    exit /b 1
)
call :log_info "Gradle task: %GRADLE_TASK%"
call :log_info "Gradle runner: %GRADLE_RUNNER%"
call :log_info "Gradle output will be streamed below."
if /I "%GRADLE_RUNNER%"=="gradlew.bat" (call "%GRADLE_DIR%\gradlew.bat" %GRADLE_TASK%) else (call "%GRADLE_RUNNER%" %GRADLE_TASK%)
set "GRADLE_RESULT=%ERRORLEVEL%"
popd
set "JAVA_HOME=%ORIGINAL_JAVA_HOME%"
set "PATH=%ORIGINAL_PATH%"
call :log_info "APK search root: %APK_SEARCH_ROOT%"

if not "%GRADLE_RESULT%"=="0" (
    call :log_error "%PROJECT_NAME% build failed."
    exit /b 1
)

  for /r "%APK_SEARCH_ROOT%" %%F in (*.apk) do (
      if not defined APK_SOURCE set "APK_SOURCE=%%F"
  )

  if "%APK_SOURCE%"=="" (
      call :log_warn "%PROJECT_NAME% APK not found after build."
      exit /b 1
  )

copy /Y "%APK_SOURCE%" "%APKS_DIR%\%APK_NAME%" >nul
if %ERRORLEVEL%==0 (
    for %%A in ("%APKS_DIR%\%APK_NAME%") do set "APK_SIZE=%%~zA"
    call :log_ok "%PROJECT_NAME% APK copied: %APKS_DIR%\%APK_NAME% (!APK_SIZE! bytes)"
    exit /b 0
)

call :log_error "Failed to copy %PROJECT_NAME% APK."
exit /b 1

:sync_gradle_local_properties
if not defined ANDROID_SDK_ROOT (
    call :log_error "ANDROID_SDK_ROOT is not set. Cannot write local.properties."
    exit /b 1
)

set "LOCAL_PROPERTIES_FILE=%~1\local.properties"
set "SDK_DIR_VALUE=%ANDROID_SDK_ROOT%"
set "SDK_DIR_VALUE=%SDK_DIR_VALUE:\=/%"

> "%LOCAL_PROPERTIES_FILE%" (
    echo ## Auto-generated by build.bat
    echo # Local SDK path for Gradle
    echo sdk.dir=%SDK_DIR_VALUE%
)

if errorlevel 1 (
    call :log_error "Failed to write local.properties: %LOCAL_PROPERTIES_FILE%"
    exit /b 1
)

call :log_info "Synced local.properties: %LOCAL_PROPERTIES_FILE%"
call :log_info "Gradle sdk.dir: %SDK_DIR_VALUE%"
exit /b 0

:run_logged
set "LOG_FILE_BASE=%~dpn1"
set "LOG_FILE_EXT=%~x1"
set "LOG_FILE=%LOG_FILE_BASE%-%RANDOM%%LOG_FILE_EXT%"
set "RUN_CMD=%~2"
cmd /d /c "%RUN_CMD%" >"%LOG_FILE%" 2>&1
set "CMD_RESULT=%ERRORLEVEL%"
call :print_log_file "%LOG_FILE%"
exit /b %CMD_RESULT%

:print_log_file
if not exist "%~1" exit /b 0
for /f "usebackq delims=" %%L in ("%~1") do (
    set "LOG_LINE=%%L"
    call :print_log_line
)
exit /b 0

:print_log_line
if not defined LOG_LINE (
    echo.
    exit /b 0
)

set "IS_ERROR="
set "IS_WARN="

if /I not "!LOG_LINE:ERROR=!"=="!LOG_LINE!" set "IS_ERROR=1"
if /I not "!LOG_LINE:FAILED=!"=="!LOG_LINE!" set "IS_ERROR=1"
if /I not "!LOG_LINE:EXCEPTION=!"=="!LOG_LINE!" set "IS_ERROR=1"
if /I not "!LOG_LINE:FATAL=!"=="!LOG_LINE!" set "IS_ERROR=1"
if /I not "!LOG_LINE:WARNING=!"=="!LOG_LINE!" set "IS_WARN=1"
if /I not "!LOG_LINE:WARN=!"=="!LOG_LINE!" set "IS_WARN=1"

if defined IS_ERROR (
    echo(!COLOR_RED!!LOG_LINE!!COLOR_RESET!
    exit /b 0
)

if defined IS_WARN (
    echo(!COLOR_YELLOW!!LOG_LINE!!COLOR_RESET!
    exit /b 0
)

echo(!LOG_LINE!
exit /b 0

:log_info
call :echo_color "%COLOR_CYAN%" "[INFO] %~1"
exit /b 0

:log_warn
call :echo_color "%COLOR_YELLOW%" "[WARN] %~1"
exit /b 0

:log_error
call :echo_color "%COLOR_RED%" "[ERR ] %~1"
exit /b 0

:log_ok
call :echo_color "%COLOR_GREEN%" "[ OK ] %~1"
exit /b 0

:echo_color
echo %~1%~2%COLOR_RESET%
exit /b 0

:finish_success
set "FINAL_EXIT_CODE=0"
goto finish_common

:finish_failed
set "FINAL_EXIT_CODE=1"

:finish_common
echo.
pause
exit /b %FINAL_EXIT_CODE%

:failed
echo.
call :log_error "Build failed. Please check errors above."
echo.
goto finish_failed

:main
set BUILD_SO=1
set BUILD_PCK=1
set BUILD_COPY=1
set BUILD_APK_SERVICE=1
set BUILD_APK_LIB=1
set CLEAN_APKS=0
set CLEAN_PCK=0
set "APK_BUILD_TYPE=Debug"
set "APK_VARIANT_DIR=debug"
goto parse_args

:init_apk_naming_meta
REM ===== APK 命名通用元数据（构建 APK 前调用一次；递归子进程不执行此处）=====
set "APK_PROJECT_NAME=MESample"
set "GIT_COMMIT="
for /f "delims=" %%C in ('git -C "%REPO_ROOT%" rev-parse --short HEAD 2^>nul') do set "GIT_COMMIT=%%C"
if not defined GIT_COMMIT set "GIT_COMMIT=unknown"
set "ENGINE_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$e=Get-Item -LiteralPath '%MATRIX_EDITOR%'; if ($e.BaseName -match 'Matrix[0-9]+(\.[0-9]+)+') { $matches[0] }"`) do set "ENGINE_VERSION=%%V"
if not defined ENGINE_VERSION set "ENGINE_VERSION=Matrix"
set "VERSION_CODE_SEQ_FILE=%LOG_DIR%\apk-versioncode.txt"
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyMMddHH"`) do set "VC_DATE_HOUR=%%T"
set "VC_SEQ=0"
if exist "%VERSION_CODE_SEQ_FILE%" (
    for /f "usebackq tokens=1,2 delims=:" %%A in ("%VERSION_CODE_SEQ_FILE%") do (
        if "%%A"=="!VC_DATE_HOUR!" set "VC_SEQ=%%B"
    )
)
set /a "VC_NEXT=VC_SEQ+1"
if !VC_NEXT! lss 10 (set "VC_SEQ_PAD=0!VC_NEXT!") else (set "VC_SEQ_PAD=!VC_NEXT!")
set "VERSION_CODE=%VC_DATE_HOUR%!VC_SEQ_PAD!"
> "%VERSION_CODE_SEQ_FILE%" echo %VC_DATE_HOUR%:!VC_NEXT!
call :log_info "APK naming meta: git=%GIT_COMMIT% engine=%ENGINE_VERSION% versionCode=%VERSION_CODE%"
exit /b 0

:compose_apk_name
REM 入参: COMPONENT / LIBS_DIR / APK_RES_FPS; 输出: APK_NAME
set "VERSION_NAME=1.0"
for /f "delims=" %%A in ('dir /b "!LIBS_DIR!\*.aar" 2^>nul') do (
    for /f "tokens=3 delims=_" %%V in ("%%A") do set "VERSION_NAME=%%V"
)
if "%VERSION_NAME%"=="" set "VERSION_NAME=1.0"
set "APK_NAME=%APK_PROJECT_NAME%_%COMPONENT%_%VERSION_NAME%_%GIT_COMMIT%_%VERSION_CODE%_%ENGINE_VERSION%_%APK_VARIANT_DIR%"
if defined APK_RES_FPS set "APK_NAME=%APK_NAME%_%APK_RES_FPS%"
set "APK_NAME=%APK_NAME%.apk"
call :log_info "APK name: %APK_NAME%"
exit /b 0