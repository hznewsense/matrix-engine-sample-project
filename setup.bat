@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM MESample Environment Setup
REM ============================================================

for /F "delims=" %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"
set "COLOR_RESET=%ESC%[0m"
set "COLOR_RED=%ESC%[91m"
set "COLOR_YELLOW=%ESC%[93m"
set "COLOR_GREEN=%ESC%[92m"
set "COLOR_CYAN=%ESC%[96m"
set LF=^


set "LOG_INFO=echo %COLOR_CYAN%[INFO] "
set "LOG_WARN=echo %COLOR_YELLOW%[WARN] "
set "LOG_ERROR=echo %COLOR_RED%[ERR ] "
set "LOG_OK=echo %COLOR_GREEN%[ OK ] "

set "NDK_VERSION=28.1.13356709"
set "GRADLE_VERSION=8.13"
set "ANDROID_COMPILE_SDK=36"
set "ANDROID_BUILD_TOOLS=36.0.0"
set "GRADLE_DIST_URL=https://mirrors.aliyun.com/macports/distfiles/gradle/gradle-8.13-bin.zip"
set "LOCAL_GRADLE_DIR=%~dp0.tools\gradle\gradle-8.13"
set "LOCAL_GRADLE_CMD=%LOCAL_GRADLE_DIR%\bin\gradle.bat"
set "USER_ENV_FILE=%~dp0.setup-user-env.cmd"

set "SKIP_JDK=0"
set "SKIP_WINGET=0"
set "PERSIST_ENV=0"
set "NO_PAUSE=0"
set "WINGET_CMD="

if exist "%USER_ENV_FILE%" call "%USER_ENV_FILE%"

goto main

:run_setup

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--skip-jdk" set "SKIP_JDK=1"
if /I "%~1"=="--skip-winget" set "SKIP_WINGET=1"
if /I "%~1"=="--persist-env" set "PERSIST_ENV=1"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
if /I "%~1"=="--help" goto usage
shift
goto parse_args

:args_done
call :print_header

call :resolve_winget

call :check_python
if errorlevel 1 goto failed

call :check_scons
if errorlevel 1 goto failed

if "%SKIP_JDK%"=="0" (
    call :resolve_java_home
    if errorlevel 1 goto failed
) else (
    call :log_info "Skipping JDK check (--skip-jdk)."
)

call :resolve_android_sdk
if errorlevel 1 goto failed

call :ensure_android_sdk_packages
if errorlevel 1 goto failed

call :resolve_android_ndk
if errorlevel 1 goto failed

call :ensure_gradle_version
if errorlevel 1 goto failed

if "%PERSIST_ENV%"=="1" (
    call :persist_env "ANDROID_HOME" "%ANDROID_HOME%"
    call :persist_env "ANDROID_SDK_ROOT" "%ANDROID_SDK_ROOT%"
    call :persist_env "ANDROID_NDK_ROOT" "%ANDROID_NDK_ROOT%"
    if "%SKIP_JDK%"=="0" call :persist_env "JAVA_HOME" "%JAVA_HOME%"
) else (
    echo %COLOR_CYAN%[INFO] Environment variables are only applied to the current setup.bat process.%COLOR_RESET%
    echo %COLOR_CYAN%[INFO] Use --persist-env if you want to write them with setx.%COLOR_RESET%
)
call :save_user_build_env

echo.
echo %COLOR_GREEN%[ OK ] Environment setup complete.%COLOR_RESET%
echo.
echo Resolved environment:
echo   ANDROID_HOME     = %ANDROID_HOME%
echo   ANDROID_SDK_ROOT = %ANDROID_SDK_ROOT%
echo   ANDROID_NDK_ROOT = %ANDROID_NDK_ROOT%
if "%SKIP_JDK%"=="0" echo   JAVA_HOME        = %JAVA_HOME%
echo.
echo %COLOR_GREEN%[ OK ] You can now run: build.bat%COLOR_RESET%
exit /b 0

:usage
echo.
echo Usage:
echo   setup.bat [options]
echo.
echo Options:
echo   --skip-jdk       Skip JDK detection and persistence
echo   --skip-winget    Disable automatic winget installs
echo   --persist-env    Persist resolved environment variables with setx
echo   --no-pause       Exit immediately after finishing
echo   --help           Show help
echo.
exit /b 0

:print_header
echo ============================================================
echo MESample Environment Setup
echo ============================================================
echo Repository Root : %~dp0
echo Target NDK      : %NDK_VERSION%
echo Target Gradle   : %GRADLE_VERSION%
echo Compile SDK     : %ANDROID_COMPILE_SDK%
echo Build Tools     : %ANDROID_BUILD_TOOLS%
echo ============================================================
echo.
exit /b 0

:check_python
call :log_info "Checking Python..."
set "PYTHON_CMD="

call :locate_python

if "!PYTHON_CMD!"=="" (
    call :log_warn "Python 3 not found. Attempting automatic install..."
    call :install_python
    if errorlevel 1 (
        call :log_error "Python 3 not found and automatic install is unavailable or failed."
        exit /b 1
    )
    set "PYTHON_CMD="
    py -3 --version >nul 2>nul
    if not errorlevel 1 set "PYTHON_CMD=py -3"
    if "!PYTHON_CMD!"=="" (
        python --version >nul 2>nul
        if not errorlevel 1 set "PYTHON_CMD=python"
    )
    if "!PYTHON_CMD!"=="" (
        for /d %%P in ("%LOCALAPPDATA%\Programs\Python\Python*") do (
            if "!PYTHON_CMD!"=="" if exist "%%~fP\python.exe" (
                set "PYTHON_CMD=%%~fP\python.exe"
            )
        )
    )
    if "!PYTHON_CMD!"=="" (
        call :log_error "Python 3 install completed, but Python command is still unavailable in this shell."
        exit /b 1
    )
)

call :log_ok "Python command: !PYTHON_CMD!"
exit /b 0

:locate_python
set "PYTHON_CMD="

py -3 --version >nul 2>nul
if not errorlevel 1 set "PYTHON_CMD=py -3"
if "!PYTHON_CMD!"=="" (
    python --version >nul 2>nul
    if not errorlevel 1 set "PYTHON_CMD=python"
)
if "!PYTHON_CMD!"=="" (
    for /d %%P in ("%LOCALAPPDATA%\Programs\Python\Python*") do (
        if "!PYTHON_CMD!"=="" if exist "%%~fP\python.exe" (
            set "PYTHON_CMD=%%~fP\python.exe"
        )
    )
)
exit /b 0

:install_python
if "%SKIP_WINGET%"=="1" (
    call :log_error "Automatic Python install requires winget, but --skip-winget is enabled."
    exit /b 1
)
if not defined WINGET_CMD (
    call :log_error "Automatic Python install is unsupported on this machine because winget is unavailable."
    exit /b 1
)

call :log_info "Installing Python 3 via winget..."
call :log_info "This step may take several minutes. Installer output will be shown below."
call "%WINGET_CMD%" install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements --disable-interactivity
if errorlevel 1 (
    call :log_error "winget failed while installing Python 3."
    exit /b 1
)
call :log_ok "Python install completed"
exit /b 0

:check_scons
call :log_info "Checking SCons..."
set "SCONS_CMD="

for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$cmd = Get-Command scons -ErrorAction SilentlyContinue; if ($cmd) { $cmd.Source }"`) do (
    set "SCONS_CMD=%%S"
)
if "!SCONS_CMD!"=="" (
    where scons >nul 2>nul
    if not errorlevel 1 set "SCONS_CMD=scons"
)
if "!SCONS_CMD!"=="" (
    !PYTHON_CMD! -m SCons --version >nul 2>nul
    if not errorlevel 1 set "SCONS_CMD=!PYTHON_CMD! -m SCons"
)

if "!SCONS_CMD!"=="" (
    call :log_warn "SCons not found. Attempting automatic install..."
    call :install_scons
    if errorlevel 1 (
        call :log_error "SCons not found and automatic install failed."
        exit /b 1
    )
    set "SCONS_CMD="
    for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$cmd = Get-Command scons -ErrorAction SilentlyContinue; if ($cmd) { $cmd.Source }"`) do (
        set "SCONS_CMD=%%S"
    )
    if "!SCONS_CMD!"=="" (
        where scons >nul 2>nul
        if not errorlevel 1 set "SCONS_CMD=scons"
    )
    if "!SCONS_CMD!"=="" (
        !PYTHON_CMD! -m SCons --version >nul 2>nul
        if not errorlevel 1 set "SCONS_CMD=!PYTHON_CMD! -m SCons"
    )
    if "!SCONS_CMD!"=="" (
        call :log_error "SCons install completed, but SCons command is still unavailable."
        exit /b 1
    )
)

call :log_ok "SCons command: !SCONS_CMD!"
exit /b 0

:install_scons
if "!PYTHON_CMD!"=="" (
    call :log_error "Automatic SCons install requires Python 3."
    exit /b 1
)

call :log_info "Installing SCons via pip..."
call :log_info "pip output will be shown below."
!PYTHON_CMD! -m pip install scons
if errorlevel 1 (
    call :log_error "pip failed while installing SCons."
    exit /b 1
)
call :log_ok "SCons install completed"
exit /b 0

:resolve_android_sdk
call :log_info "Resolving Android SDK..."
set "SDK_CANDIDATE="

if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" set "SDK_CANDIDATE=%ANDROID_SDK_ROOT%"
if not defined SDK_CANDIDATE if defined ANDROID_HOME if exist "%ANDROID_HOME%" set "SDK_CANDIDATE=%ANDROID_HOME%"
if not defined SDK_CANDIDATE if exist "%LOCALAPPDATA%\Android\Sdk" set "SDK_CANDIDATE=%LOCALAPPDATA%\Android\Sdk"
if not defined SDK_CANDIDATE call :scan_android_studio_sdk_config
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%USERPROFILE%\AppData\Local\Android\Sdk"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%ProgramFiles%\Android\Sdk"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%SystemDrive%\Android\Sdk"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\Android\Sdk"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\WorkTools\SDK"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\SDK\Android"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\Android\Sdk"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\WorkTools\SDK"
if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\SDK\Android"

if not defined SDK_CANDIDATE (
    call :prompt_for_android_sdk
    if defined SDK_CANDIDATE goto sdk_found

    call :confirm_android_sdk_install
    if errorlevel 1 (
        call :log_error "Android SDK not found. Please install it or rerun setup and provide the SDK path."
        exit /b 1
    )

    call :log_warn "Android SDK not found. Attempting Android SDK install..."
    call :install_android_sdk
    if errorlevel 1 (
        call :log_error "Android SDK not found and automatic install is unavailable or failed."
        exit /b 1
    )
    if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" set "SDK_CANDIDATE=%ANDROID_SDK_ROOT%"
    if not defined SDK_CANDIDATE if defined ANDROID_HOME if exist "%ANDROID_HOME%" set "SDK_CANDIDATE=%ANDROID_HOME%"
    if not defined SDK_CANDIDATE if exist "%LOCALAPPDATA%\Android\Sdk" set "SDK_CANDIDATE=%LOCALAPPDATA%\Android\Sdk"
    if not defined SDK_CANDIDATE call :scan_android_studio_sdk_config
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%USERPROFILE%\AppData\Local\Android\Sdk"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%ProgramFiles%\Android\Sdk"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "%SystemDrive%\Android\Sdk"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\Android\Sdk"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\WorkTools\SDK"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "D:\SDK\Android"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\Android\Sdk"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\WorkTools\SDK"
    if not defined SDK_CANDIDATE call :try_set_sdk_candidate "E:\SDK\Android"
    if not defined SDK_CANDIDATE (
        call :prompt_for_android_sdk
    )
    if not defined SDK_CANDIDATE (
        call :log_error "Android SDK still not found after automatic install."
        exit /b 1
    )
)

:sdk_found
set "ANDROID_HOME=%SDK_CANDIDATE%"
set "ANDROID_SDK_ROOT=%SDK_CANDIDATE%"
call :log_ok "Android SDK: %ANDROID_SDK_ROOT%"
exit /b 0

:prompt_for_android_sdk
set "SDK_INPUT="
echo.
set /p SDK_INPUT=Enter an existing Android SDK path, or press Enter to continue: 
if not defined SDK_INPUT exit /b 0
if exist "%SDK_INPUT%" (
    set "SDK_CANDIDATE=%SDK_INPUT%"
    set "ANDROID_HOME=%SDK_INPUT%"
    set "ANDROID_SDK_ROOT=%SDK_INPUT%"
    call :log_ok "Using user-provided Android SDK path: %SDK_INPUT%"
    setx ANDROID_HOME "%SDK_INPUT%" >nul
    setx ANDROID_SDK_ROOT "%SDK_INPUT%" >nul
    if errorlevel 1 (
        call :log_warn "Failed to persist user-provided Android SDK path."
    ) else (
        call :log_ok "Persisted user-provided Android SDK path"
    )
    call :save_user_android_sdk "%SDK_INPUT%"
    exit /b 0
)
call :log_warn "The provided Android SDK path does not exist: %SDK_INPUT%"
set "SDK_INPUT="
exit /b 0

:save_user_android_sdk
> "%USER_ENV_FILE%" (
    echo @echo off
    echo set "ANDROID_HOME=%~1"
    echo set "ANDROID_SDK_ROOT=%~1"
)
call :log_ok "Saved Android SDK path for future setup runs"
exit /b 0

:save_user_build_env
> "%USER_ENV_FILE%" (
    echo @echo off
    if defined ANDROID_HOME echo set "ANDROID_HOME=%ANDROID_HOME%"
    if defined ANDROID_SDK_ROOT echo set "ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%"
    if defined ANDROID_NDK_ROOT echo set "ANDROID_NDK_ROOT=%ANDROID_NDK_ROOT%"
    if defined JAVA_HOME echo set "JAVA_HOME=%JAVA_HOME%"
    if defined SCONS_CMD echo set "SCONS_CMD=%SCONS_CMD%"
)
call :log_ok "Saved build environment for future runs"
exit /b 0

:confirm_android_sdk_install
echo.
set "SDK_INSTALL_CONFIRM="
set /p SDK_INSTALL_CONFIRM=Android SDK was not found. If it is not installed, type Y to install Android SDK now; otherwise press Enter to cancel: 
if /I "%SDK_INSTALL_CONFIRM%"=="Y" exit /b 0
if /I "%SDK_INSTALL_CONFIRM%"=="YES" exit /b 0
exit /b 1

:resolve_android_cli
set "ANDROID_CLI_CMD="
where android >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%A in ('where android') do (
        if not defined ANDROID_CLI_CMD set "ANDROID_CLI_CMD=%%~fA"
    )
)
if not defined ANDROID_CLI_CMD if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages" (
    for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\Google.AndroidCLI*") do (
        if not defined ANDROID_CLI_CMD if exist "%%~fD\android.exe" set "ANDROID_CLI_CMD=%%~fD\android.exe"
    )
)
if not defined ANDROID_CLI_CMD if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\android.exe" (
    set "ANDROID_CLI_CMD=%LOCALAPPDATA%\Microsoft\WinGet\Links\android.exe"
)
exit /b 0

:scan_android_studio_sdk_config
set "ANDROID_STUDIO_CONFIG=%APPDATA%\Google\AndroidStudio\options\other.xml"
if not exist "%ANDROID_STUDIO_CONFIG%" set "ANDROID_STUDIO_CONFIG=%APPDATA%\Google\AndroidStudio2024.1\options\other.xml"
if not exist "%ANDROID_STUDIO_CONFIG%" set "ANDROID_STUDIO_CONFIG=%APPDATA%\Google\AndroidStudio2024.2\options\other.xml"
if not exist "%ANDROID_STUDIO_CONFIG%" set "ANDROID_STUDIO_CONFIG=%APPDATA%\Google\AndroidStudio2024.3\options\other.xml"
if not exist "%ANDROID_STUDIO_CONFIG%" exit /b 0

call :log_info "Checking Android Studio SDK config: %ANDROID_STUDIO_CONFIG%"
set "ANDROID_STUDIO_SDK_TMP=%TEMP%\mesample-android-sdk-%RANDOM%.txt"
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $xml = [xml](Get-Content -LiteralPath '%ANDROID_STUDIO_CONFIG%'); $node = $xml.SelectSingleNode('//option[@name=""android.sdk.path""]'); if ($node) { [Console]::WriteLine($node.GetAttribute('value')) }" > "%ANDROID_STUDIO_SDK_TMP%" 2>nul
for /f "usebackq delims=" %%P in ("%ANDROID_STUDIO_SDK_TMP%") do (
    if not "%%~P"=="" (
        call :log_info "Android Studio configured SDK path: %%~P"
        if not defined SDK_CANDIDATE if exist "%%~fP" set "SDK_CANDIDATE=%%~fP"
    )
)
del /q "%ANDROID_STUDIO_SDK_TMP%" >nul 2>nul
exit /b 0

:scan_sdkmanager_root
if defined SDK_CANDIDATE exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

call :log_info "Scanning sdkmanager under: %~1"
for /f "delims=" %%S in ('dir /s /b "%~1\sdkmanager.bat" 2^>nul') do (
    if not defined SDK_CANDIDATE (
        set "SDKMANAGER_PATH=%%~fS"
        echo(!SDKMANAGER_PATH!| findstr /i "\\cmdline-tools\\" >nul
        if not errorlevel 1 (
            for %%R in ("%%~dpS..\..\..") do (
                if not defined SDK_CANDIDATE if exist "%%~fR" set "SDK_CANDIDATE=%%~fR"
            )
        )
        if not defined SDK_CANDIDATE (
            echo(!SDKMANAGER_PATH!| findstr /i "\\tools\\bin\\" >nul
            if not errorlevel 1 (
                for %%R in ("%%~dpS..\..") do (
                    if not defined SDK_CANDIDATE if exist "%%~fR" set "SDK_CANDIDATE=%%~fR"
                )
            )
        )
        if defined SDK_CANDIDATE call :log_info "Derived Android SDK from sdkmanager: !SDK_CANDIDATE!"
    )
)
set "SDKMANAGER_PATH="
exit /b 0

:try_set_sdk_candidate
if defined SDK_CANDIDATE exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

if exist "%~1\platform-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\cmdline-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\build-tools" set "SDK_CANDIDATE=%~1"
if not defined SDK_CANDIDATE if exist "%~1\platforms" set "SDK_CANDIDATE=%~1"
exit /b 0

:install_android_sdk
if "%SKIP_WINGET%"=="1" (
    call :log_error "Automatic Android SDK install requires winget, but --skip-winget is enabled."
    exit /b 1
)
if not defined WINGET_CMD (
    call :log_error "Automatic Android SDK install is unsupported on this machine because winget is unavailable."
    exit /b 1
)

call :resolve_android_cli
if not defined ANDROID_CLI_CMD (
    call :log_info "Installing Android CLI via winget..."
    call :log_info "This step may take several minutes. Installer output will be shown below."
    call "%WINGET_CMD%" install --id Google.AndroidCLI -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    if errorlevel 1 (
        call :log_error "winget failed while installing Android CLI."
        exit /b 1
    )
    call :resolve_android_cli
    if not defined ANDROID_CLI_CMD (
        call :log_error "Android CLI install completed, but the android command is still unavailable."
        exit /b 1
    )
    call :log_ok "Android CLI install completed"
)

set "SDK_INSTALL_ROOT=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_SDK_ROOT set "SDK_INSTALL_ROOT=%ANDROID_SDK_ROOT%"
if defined ANDROID_HOME set "SDK_INSTALL_ROOT=%ANDROID_HOME%"
if not exist "%SDK_INSTALL_ROOT%" mkdir "%SDK_INSTALL_ROOT%" >nul 2>nul

call :log_info "Installing Android SDK packages via Android CLI..."
call :log_info "This step may take several minutes. Installer output will be shown below."
call :log_info "Target SDK root: %SDK_INSTALL_ROOT%"
call "%ANDROID_CLI_CMD%" --sdk="%SDK_INSTALL_ROOT%" sdk install cmdline-tools/latest platform-tools platforms/android-%ANDROID_COMPILE_SDK% build-tools/%ANDROID_BUILD_TOOLS%
if errorlevel 1 (
    call :log_error "Android CLI failed while installing Android SDK packages."
    exit /b 1
)
set "SDK_CANDIDATE=%SDK_INSTALL_ROOT%"
set "ANDROID_HOME=%SDK_INSTALL_ROOT%"
set "ANDROID_SDK_ROOT=%SDK_INSTALL_ROOT%"
setx ANDROID_HOME "%SDK_INSTALL_ROOT%" >nul
setx ANDROID_SDK_ROOT "%SDK_INSTALL_ROOT%" >nul
call :save_user_android_sdk "%SDK_INSTALL_ROOT%"
call :log_ok "Android SDK install completed"
exit /b 0

:ensure_android_sdk_packages
call :log_info "Checking Android SDK platform and build tools..."

call :resolve_sdkmanager
if errorlevel 1 (
    call :install_android_cmdline_tools
    if errorlevel 1 (
        call :log_error "sdkmanager.bat not found. Android command-line tools are required."
        exit /b 1
    )
    call :resolve_sdkmanager
    if errorlevel 1 (
        call :log_error "sdkmanager.bat not found after Android command-line tools install."
        exit /b 1
    )
)

call :prepare_java_for_sdkmanager
if errorlevel 1 (
    call :log_error "JDK not found. sdkmanager requires JDK/JBR to manage Android SDK packages."
    exit /b 1
)

set "SDK_PACKAGES_MISSING=0"
if not exist "%ANDROID_SDK_ROOT%\platforms\android-%ANDROID_COMPILE_SDK%\android.jar" set "SDK_PACKAGES_MISSING=1"
if not exist "%ANDROID_SDK_ROOT%\build-tools\%ANDROID_BUILD_TOOLS%\aapt2.exe" set "SDK_PACKAGES_MISSING=1"

if "%SDK_PACKAGES_MISSING%"=="0" (
    call :log_ok "Android SDK platform and build tools are ready"
    exit /b 0
)

call :log_warn "Android SDK packages are missing. Installing required platform and build tools..."
call :log_info "sdkmanager will now run. It may take several minutes before new lines appear."
call :log_info "Target packages: platforms;android-%ANDROID_COMPILE_SDK%, build-tools;%ANDROID_BUILD_TOOLS%"
set "SDKMANAGER_INPUT=%TEMP%\mesample-sdkmanager-input-%RANDOM%.txt"
> "%SDKMANAGER_INPUT%" (
    echo y
    echo y
    echo y
    echo y
    echo y
)
call :log_info "Streaming sdkmanager output below..."
cmd /d /c ""%JAVA_HOME%\bin\java.exe" -version & call "%SDKMANAGER_CMD%" --sdk_root="%ANDROID_SDK_ROOT%" "platforms;android-%ANDROID_COMPILE_SDK%" "build-tools;%ANDROID_BUILD_TOOLS%" < "%SDKMANAGER_INPUT%""
set "SDKMANAGER_RESULT=%ERRORLEVEL%"
del /q "%SDKMANAGER_INPUT%" >nul 2>nul

if not "%SDKMANAGER_RESULT%"=="0" (
    call :log_error "sdkmanager failed while installing Android platform/build-tools."
    call :log_error "Android repository metadata could not be downloaded on this machine."
    call :log_error "Please check network/proxy access for sdkmanager, or install these packages manually:"
    call :log_error "  platforms;android-%ANDROID_COMPILE_SDK%"
    call :log_error "  build-tools;%ANDROID_BUILD_TOOLS%"
    exit /b 1
)

if not exist "%ANDROID_SDK_ROOT%\platforms\android-%ANDROID_COMPILE_SDK%\android.jar" (
    call :log_error "Android platform android-%ANDROID_COMPILE_SDK% is still missing after install."
    exit /b 1
)
if not exist "%ANDROID_SDK_ROOT%\build-tools\%ANDROID_BUILD_TOOLS%\aapt2.exe" (
    call :log_error "Android build-tools %ANDROID_BUILD_TOOLS% is still missing after install."
    exit /b 1
)

call :log_ok "Android SDK platform and build tools are ready"
exit /b 0

:install_android_cmdline_tools
call :log_warn "sdkmanager.bat not found. Attempting to install Android command-line tools..."
call :resolve_android_cli
if not defined ANDROID_CLI_CMD (
    call :log_error "Android CLI is unavailable, cannot install Android command-line tools automatically."
    exit /b 1
)

set "SDK_INSTALL_ROOT=%ANDROID_SDK_ROOT%"
if not defined SDK_INSTALL_ROOT set "SDK_INSTALL_ROOT=%ANDROID_HOME%"
if not defined SDK_INSTALL_ROOT set "SDK_INSTALL_ROOT=%LOCALAPPDATA%\Android\Sdk"
if not exist "%SDK_INSTALL_ROOT%" mkdir "%SDK_INSTALL_ROOT%" >nul 2>nul

call :log_info "Installing Android command-line tools via Android CLI..."
call :log_info "Target SDK root: %SDK_INSTALL_ROOT%"
call "%ANDROID_CLI_CMD%" --sdk="%SDK_INSTALL_ROOT%" sdk install cmdline-tools/latest
if errorlevel 1 (
    call :log_error "Android CLI failed while installing Android command-line tools."
    exit /b 1
)

set "ANDROID_HOME=%SDK_INSTALL_ROOT%"
set "ANDROID_SDK_ROOT=%SDK_INSTALL_ROOT%"
call :log_ok "Android command-line tools install completed"
exit /b 0

:resolve_android_ndk
call :log_info "Resolving Android NDK %NDK_VERSION%..."
set "NDK_CANDIDATE="
set "NDK_CLANG="
if defined ANDROID_NDK_ROOT if exist "%ANDROID_NDK_ROOT%\source.properties" set "NDK_CANDIDATE=%ANDROID_NDK_ROOT%"
if not defined NDK_CANDIDATE if exist "%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%"
if not defined NDK_CANDIDATE if exist "%ANDROID_HOME%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_HOME%\ndk\%NDK_VERSION%"
if not defined NDK_CANDIDATE (
    call :install_android_ndk
    if errorlevel 1 exit /b 1
    set "NDK_CANDIDATE="
    set "NDK_CLANG="
    if defined ANDROID_NDK_ROOT if exist "%ANDROID_NDK_ROOT%\source.properties" set "NDK_CANDIDATE=%ANDROID_NDK_ROOT%"
    if not defined NDK_CANDIDATE if exist "%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%"
    if not defined NDK_CANDIDATE if exist "%ANDROID_HOME%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_HOME%\ndk\%NDK_VERSION%"
    if not defined NDK_CANDIDATE (
        call :log_error "Android NDK %NDK_VERSION% install finished but validation still failed."
        exit /b 1
    )
)

set "NDK_CLANG=%NDK_CANDIDATE%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang++.exe"
if not exist "%NDK_CLANG%" (
    call :log_error "Android NDK is incomplete or invalid: %NDK_CANDIDATE%"
    call :log_error "Missing toolchain: %NDK_CLANG%"
    exit /b 1
)

set "ANDROID_NDK_ROOT=%NDK_CANDIDATE%"
call :log_ok "Android NDK: %ANDROID_NDK_ROOT%"
exit /b 0

:ensure_gradle_version
call :log_info "Checking Gradle %GRADLE_VERSION%..."

call :find_local_gradle
if defined LOCAL_GRADLE_CMD if exist "%LOCAL_GRADLE_CMD%" (
    call :check_gradle_version "%LOCAL_GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_ok "Gradle %GRADLE_VERSION% ready: %LOCAL_GRADLE_CMD%"
        exit /b 0
    )
    call :log_warn "Local Gradle is incompatible, ignoring: %LOCAL_GRADLE_CMD%"
    set "LOCAL_GRADLE_CMD="
)

call :find_gradle_cmd
if defined GRADLE_CMD (
    call :check_gradle_version "%GRADLE_CMD%"
    if "!GRADLE_VERSION_OK!"=="1" (
        call :log_ok "Gradle %GRADLE_VERSION% ready: %GRADLE_CMD%"
        exit /b 0
    )
    call :log_warn "Gradle from PATH is incompatible, fallback to gradle wrapper: %GRADLE_CMD%"
)

call :resolve_gradle_wrapper
if errorlevel 1 (
    call :log_error "Gradle %GRADLE_VERSION% is missing and no usable gradle wrapper was found."
    exit /b 1
)

call :prepare_java_for_gradle
if errorlevel 1 (
    call :log_error "JDK/JBR not found. Gradle %GRADLE_VERSION% cannot be initialized."
    exit /b 1
)

call :log_warn "Gradle %GRADLE_VERSION% not found locally. Using gradle wrapper for later builds."
if not exist "%GRADLE_WRAPPER_DIR%\gradle\wrapper\gradle-wrapper.jar" (
    call :log_error "Gradle wrapper jar not found: %GRADLE_WRAPPER_DIR%\gradle\wrapper\gradle-wrapper.jar"
    exit /b 1
)
call :log_ok "Gradle %GRADLE_VERSION% ready via wrapper: %GRADLE_WRAPPER_CMD%"
exit /b 0

:find_local_gradle
set "LOCAL_GRADLE_CMD="
set "GRADLE_HOME_CANDIDATE="
if defined GRADLE_HOME (
    set "GRADLE_HOME_CANDIDATE=%GRADLE_HOME:"=%"
    if exist "!GRADLE_HOME_CANDIDATE!\bin\gradle.bat" set "LOCAL_GRADLE_CMD=!GRADLE_HOME_CANDIDATE!\bin\gradle.bat"
)
if not defined LOCAL_GRADLE_CMD if exist "%~dp0.tools\gradle\gradle-8.13\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%~dp0.tools\gradle\gradle-8.13\bin\gradle.bat"
if not defined LOCAL_GRADLE_CMD if exist "%USERPROFILE%\.gradle\wrapper\dists\gradle-8.13-bin" (
    for /d %%D in ("%USERPROFILE%\.gradle\wrapper\dists\gradle-8.13-bin\*") do (
        if not defined LOCAL_GRADLE_CMD if exist "%%~fD\gradle-8.13\bin\gradle.bat" set "LOCAL_GRADLE_CMD=%%~fD\gradle-8.13\bin\gradle.bat"
    )
)
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

:find_gradle_cmd
set "GRADLE_CMD="

where gradle >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%G in ('where gradle') do (
        if not defined GRADLE_CMD set "GRADLE_CMD=%%G"
    )
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

:resolve_gradle_wrapper
set "GRADLE_WRAPPER_CMD="
set "GRADLE_WRAPPER_DIR="

if exist "%~dp0MESampleJava\MatrixRenderAsAAR\gradlew.bat" (
    set "GRADLE_WRAPPER_CMD=%~dp0MESampleJava\MatrixRenderAsAAR\gradlew.bat"
    set "GRADLE_WRAPPER_DIR=%~dp0MESampleJava\MatrixRenderAsAAR"
    exit /b 0
)

if exist "%~dp0MESampleJava\MatrixRenderAsService\gradlew.bat" (
    set "GRADLE_WRAPPER_CMD=%~dp0MESampleJava\MatrixRenderAsService\gradlew.bat"
    set "GRADLE_WRAPPER_DIR=%~dp0MESampleJava\MatrixRenderAsService"
    exit /b 0
)

exit /b 1

:prepare_java_for_gradle
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" (
    call :check_java_version "%JAVA_HOME%\bin\java.exe"
    if "!JAVA_VERSION_OK!"=="1" exit /b 0
)

call :locate_java_home
if errorlevel 1 exit /b 1

set "JAVA_HOME=%JAVA_CANDIDATE%"
call :log_info "Using JAVA_HOME for Gradle: %JAVA_HOME%"
exit /b 0

:find_android_ndk
set "NDK_CANDIDATE="
set "NDK_CLANG="

if defined ANDROID_NDK_ROOT if exist "%ANDROID_NDK_ROOT%\source.properties" set "NDK_CANDIDATE=%ANDROID_NDK_ROOT%"
if not defined NDK_CANDIDATE if exist "%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_SDK_ROOT%\ndk\%NDK_VERSION%"
if not defined NDK_CANDIDATE if exist "%ANDROID_HOME%\ndk\%NDK_VERSION%\source.properties" set "NDK_CANDIDATE=%ANDROID_HOME%\ndk\%NDK_VERSION%"

if not defined NDK_CANDIDATE (
    exit /b 1
)

set "NDK_CLANG=%NDK_CANDIDATE%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang++.exe"
if not exist "%NDK_CLANG%" (
    call :log_error "Android NDK is incomplete or invalid: %NDK_CANDIDATE%"
    call :log_error "Missing toolchain: %NDK_CLANG%"
    exit /b 1
)

exit /b 0

:install_android_ndk
call :log_warn "Android NDK %NDK_VERSION% not found. Installing via sdkmanager..."
call :log_info "sdkmanager will now run. It may take several minutes before new lines appear."
call :log_info "Target package: ndk;%NDK_VERSION%"

call :resolve_sdkmanager
if errorlevel 1 (
    call :log_error "sdkmanager.bat not found. Install Android command-line tools first."
    exit /b 1
)

call :prepare_java_for_sdkmanager
if errorlevel 1 (
    call :log_error "JDK not found. sdkmanager requires JDK/JBR to install Android NDK."
    exit /b 1
)

if not exist "%TEMP%" (
    call :log_error "TEMP directory not available."
    exit /b 1
)

set "SDKMANAGER_INPUT=%TEMP%\mesample-sdkmanager-input-%RANDOM%.txt"
> "%SDKMANAGER_INPUT%" (
    echo y
    echo y
    echo y
    echo y
    echo y
)
call :log_info "Streaming sdkmanager output below..."
cmd /d /c ""%JAVA_HOME%\bin\java.exe" -version & call "%SDKMANAGER_CMD%" --sdk_root="%ANDROID_SDK_ROOT%" "ndk;%NDK_VERSION%" < "%SDKMANAGER_INPUT%""
set "SDKMANAGER_RESULT=%ERRORLEVEL%"
del /q "%SDKMANAGER_INPUT%" >nul 2>nul

if not "%SDKMANAGER_RESULT%"=="0" (
    call :log_error "sdkmanager failed while installing Android NDK %NDK_VERSION%."
    call :log_error "Android repository metadata could not be downloaded on this machine."
    call :log_error "Please check network/proxy access for sdkmanager, or install this package manually:"
    call :log_error "  ndk;%NDK_VERSION%"
    exit /b 1
)

call :log_ok "sdkmanager install completed for ndk;%NDK_VERSION%"
exit /b 0

:resolve_sdkmanager
set "SDKMANAGER_CMD="

if exist "%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat"
if not defined SDKMANAGER_CMD (
    for /d %%D in ("%ANDROID_SDK_ROOT%\cmdline-tools\*") do (
        if not defined SDKMANAGER_CMD if exist "%%~fD\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%%~fD\bin\sdkmanager.bat"
    )
)
if not defined SDKMANAGER_CMD if exist "%ANDROID_SDK_ROOT%\tools\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%ANDROID_SDK_ROOT%\tools\bin\sdkmanager.bat"
if not defined SDKMANAGER_CMD if exist "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat"
if not defined SDKMANAGER_CMD (
    for /d %%D in ("%ANDROID_HOME%\cmdline-tools\*") do (
        if not defined SDKMANAGER_CMD if exist "%%~fD\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%%~fD\bin\sdkmanager.bat"
    )
)
if not defined SDKMANAGER_CMD if exist "%ANDROID_HOME%\tools\bin\sdkmanager.bat" set "SDKMANAGER_CMD=%ANDROID_HOME%\tools\bin\sdkmanager.bat"

if not defined SDKMANAGER_CMD exit /b 1

call :log_ok "sdkmanager: %SDKMANAGER_CMD%"
exit /b 0

:resolve_winget
set "WINGET_CMD="
if "%SKIP_WINGET%"=="1" exit /b 0

where winget >nul 2>nul
if not errorlevel 1 set "WINGET_CMD=winget"
exit /b 0

:prepare_java_for_sdkmanager
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" (
    call :check_java_version "%JAVA_HOME%\bin\java.exe"
    if "!JAVA_VERSION_OK!"=="1" exit /b 0
)

call :locate_java_home
if errorlevel 1 (
    call :log_warn "JDK 17+ not found for sdkmanager. Attempting automatic install..."
    call :install_jdk
    if errorlevel 1 exit /b 1
    call :locate_java_home
    if errorlevel 1 exit /b 1
)

set "JAVA_HOME=%JAVA_CANDIDATE%"
call :log_info "Using JAVA_HOME for sdkmanager: %JAVA_HOME%"
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

:resolve_java_home
call :log_info "Resolving JDK..."
call :locate_java_home
if errorlevel 1 (
    call :log_warn "JDK 17+ not found. Attempting automatic install..."
    call :install_jdk
    if errorlevel 1 (
        call :log_error "JDK not found and automatic install is unavailable or failed."
        exit /b 1
    )
    call :locate_java_home
    if errorlevel 1 (
        call :log_error "JDK install completed, but JDK 17+ is still unavailable."
        exit /b 1
    )
)

set "JAVA_HOME=%JAVA_CANDIDATE%"
call :log_ok "JAVA_HOME: %JAVA_HOME%"
exit /b 0

:install_jdk
if "%SKIP_WINGET%"=="1" (
    call :log_error "Automatic JDK install requires winget, but --skip-winget is enabled."
    exit /b 1
)
if not defined WINGET_CMD (
    call :log_error "Automatic JDK install is unsupported on this machine because winget is unavailable."
    exit /b 1
)

call :log_info "Installing JDK 17 via winget (preferred source: Microsoft.OpenJDK.17)..."
call :log_info "This step may take several minutes. Installer output will be shown below."
call "%WINGET_CMD%" install --id Microsoft.OpenJDK.17 -e --accept-package-agreements --accept-source-agreements --disable-interactivity
if errorlevel 1 (
    call :log_warn "Microsoft.OpenJDK.17 install failed, falling back to EclipseAdoptium.Temurin.17.JDK..."
    call "%WINGET_CMD%" install --id EclipseAdoptium.Temurin.17.JDK -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    if errorlevel 1 (
        call :log_error "winget failed while installing JDK 17."
        exit /b 1
    )
)
call :log_ok "JDK install completed"
exit /b 0

:persist_env
set "ENV_NAME=%~1"
set "ENV_VALUE=%~2"
if "%ENV_VALUE%"=="" exit /b 0

if not "%PERSIST_ENV%"=="1" (
    call :log_info "Skipping persist for %ENV_NAME% (use --persist-env to enable setx)."
    exit /b 0
)

call set "CURRENT_VALUE=%%%ENV_NAME%%%"
if /I "%CURRENT_VALUE%"=="%ENV_VALUE%" (
    call :log_info "%ENV_NAME% already set"
    exit /b 0
)

setx %ENV_NAME% "%ENV_VALUE%" >nul
if errorlevel 1 (
    call :log_warn "Failed to persist %ENV_NAME%. Current run will still use resolved value."
    exit /b 0
)

call :log_ok "Persisted %ENV_NAME%"
exit /b 0

:log_info
echo %COLOR_CYAN%[INFO] %~1%COLOR_RESET%
goto :eof

:log_warn
echo %COLOR_YELLOW%[WARN] %~1%COLOR_RESET%
goto :eof

:log_error
echo %COLOR_RED%[ERR ] %~1%COLOR_RESET%
goto :eof

:log_ok
echo %COLOR_GREEN%[ OK ] %~1%COLOR_RESET%
goto :eof

:echo_color
echo %~1%~2%COLOR_RESET%
goto :eof

:failed
echo.
echo %COLOR_RED%[ERR ] Environment setup failed.%COLOR_RESET%
echo %COLOR_RED%[ERR ] You cannot run build.bat until setup completes successfully.%COLOR_RESET%
exit /b 1

:main
call :run_setup %*
set "FINAL_EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%NO_PAUSE%"=="1" pause
exit /b %FINAL_EXIT_CODE%
