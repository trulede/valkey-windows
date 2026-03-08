@echo off
SET VALKEY_PATH=%~dp0

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%VALKEY_PATH%"
:--------------------------------------

echo 1.Please enter the valkey installation path
echo The default is the current path: %VALKEY_PATH%
echo If you don't want to modify it, press Enter
set /p VALKEY_INSTALL_PATH=Installation Path:

echo.

echo 2.Please enter the valkey configuration file path
echo The default is the current path: %VALKEY_PATH%valkey.conf
echo Must be an absolute path
echo If you don't want to modify it, press Enter
set /p VALKEY_CONF_PATH=Configuration file Path:

if defined VALKEY_INSTALL_PATH (
    if defined VALKEY_CONF_PATH (
        REM Install and Conf
        echo Installation Path: %VALKEY_INSTALL_PATH%
        echo Configuration file Path: %VALKEY_CONF_PATH%
        pause
        call:existInstallPath
        call:existConfPath
        call:installValkey
        sc.exe create "Valkey" binpath="%VALKEY_INSTALL_PATH%\ValkeyService.exe -c %VALKEY_CONF_PATH%" start= AUTO
    ) else (
        REM Install
        echo Installation Path: %VALKEY_INSTALL_PATH%
        echo Configuration file Path: %VALKEY_INSTALL_PATH%\valkey.conf
        pause
        call:existInstallPath
        call:installValkey
        sc.exe create "Valkey" binpath="%VALKEY_INSTALL_PATH%\ValkeyService.exe" start= AUTO
    )
) else (
    if defined VALKEY_CONF_PATH (
        REM Conf
        echo Installation Path: %VALKEY_PATH%
        echo Configuration file Path: %VALKEY_CONF_PATH%
        pause
        call:existConfPath
        sc.exe create "Valkey" binpath="%VALKEY_PATH%\ValkeyService.exe -c %VALKEY_CONF_PATH%" start= AUTO
    ) else (
        REM null
        echo Installation Path: %VALKEY_PATH%
        echo Configuration file Path: %VALKEY_PATH%\valkey.conf
        pause
        sc.exe create "Valkey" binpath="%VALKEY_PATH%ValkeyService.exe" start= AUTO
    )
) 

net start "Valkey"
pause

:existInstallPath
    if not exist %VALKEY_INSTALL_PATH% (
        md %VALKEY_INSTALL_PATH%
        if not exist %VALKEY_INSTALL_PATH% (
            echo Failed to create folder!
            pause
            exit 1
        )
    )
goto:eof

:existConfPath
    if not exist %VALKEY_CONF_PATH% (
        echo Configuration file does not exist!
        pause
        exit 1
    )
goto:eof

:installValkey
    xcopy %VALKEY_PATH% %VALKEY_INSTALL_PATH% /y
goto:eof
