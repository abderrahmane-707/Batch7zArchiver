@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: Default settings
set "COMPRESSION_LEVEL=9"
set "METHOD=LZMA2"
set "DICT_SIZE=auto"
set "FAST_BYTES=auto"
set "SOLID_MODE=on"
set "MULTITHREAD=on"
set "ARCHIVE_PASSWORD="
set "HEADER_ENC=1"
set "DRY_RUN=0"
set "DELETE_AFTER_VERIFY=1"

:: Internal state variables
set "TOTAL_COUNT=0"
set "SUCCESS_COUNT=0"
set "FAILED_COUNT=0"
set "FAILED_LIST="
set "FOLDER_FOUND=0"

where 7z >nul 2>nul
if %errorlevel% equ 0 (
    set "SEVENZIP_PATH=7z"
) else if exist "%PROGRAMFILES%\7-Zip\7z.exe" (
    set "SEVENZIP_PATH=%PROGRAMFILES%\7-Zip\7z.exe"
) else if exist "%PROGRAMFILES(x86)%\7-Zip\7z.exe" (
    set "SEVENZIP_PATH=%PROGRAMFILES(x86)%\7-Zip\7z.exe"
) else (
    echo 7-Zip not found in system PATH or standard directories.
    pause & exit /b 1
)

:MAIN_MENU
cls
echo ==============================================================================
echo                          7-ZIP FOLDER COMPRESSOR - MENU
echo ==============================================================================
echo    7-Zip path             : %SEVENZIP_PATH%
echo    Working directory      : %CD%
echo ------------------------------------------------------------------------------
echo    [1]  Compression level (-mx)        : %COMPRESSION_LEVEL%
echo    [2]  Compression method (-m0)       : %METHOD%
echo    [3]  Dictionary size (-md)          : %DICT_SIZE%
echo    [4]  Fast bytes (-mfb)              : %FAST_BYTES%
echo    [5]  Solid archive (-ms)            : %SOLID_MODE%
echo    [6]  Multithreading (-mmt)          : %MULTITHREAD%
if "%ARCHIVE_PASSWORD%"=="" (
    echo    [7]  Archive password ^(-p^)          : ^(none^)
) else (
    echo    [7]  Archive password ^(-p^)          : ^(set^)
)
if "%ARCHIVE_PASSWORD%"=="" (
    echo    [8]  Header encryption ^(-mhe^)       : n/a ^(requires password^)
) else (
    if "%HEADER_ENC%"=="1" (
        echo    [8]  Header encryption ^(-mhe^)       : ON
    ) else (
        echo    [8]  Header encryption ^(-mhe^)       : OFF
    )
)
if "%DRY_RUN%"=="1" (
    echo    [9]  Dry run mode                   : ON  ^(no files will be changed^)
) else (
    echo    [9]  Dry run mode                   : OFF
)
if "%DELETE_AFTER_VERIFY%"=="1" (
    echo    [10] Delete source on success       : ON  ^(after verification^)
) else (
    echo    [10] Delete source on success       : OFF
)
echo    [0] Exit
echo ==============================================================================

echo. & set "choice=" & set /p "choice=--> Select an option(s) and press [S] to Start: "
if "%choice%"=="0" exit /b
if "%choice%"=="1" goto SET_LEVEL
if "%choice%"=="2" goto SET_METHOD
if "%choice%"=="3" goto SET_DICT
if "%choice%"=="4" goto SET_FASTBYTES
if "%choice%"=="5" goto TOGGLE_SOLID
if "%choice%"=="6" goto SET_MULTITHREAD
if "%choice%"=="7" goto SET_PASSWORD
if "%choice%"=="8" goto TOGGLE_HEADERENC
if "%choice%"=="9" goto TOGGLE_DRYRUN
if "%choice%"=="10" goto TOGGLE_DELETE
if /i "%choice%"=="S" goto START_RUN

call :INVALID "(0-10)" & goto MAIN_MENU

:SET_LEVEL
set "NEW_LEVEL="
echo. & set /p "NEW_LEVEL=Enter compression level (0-9): "
echo %NEW_LEVEL%| findstr /r "^[0-9]$" >nul
if errorlevel 1 (
    echo Invalid value, must be a single digit 0-9
    pause & goto MAIN_MENU
)
set "COMPRESSION_LEVEL=%NEW_LEVEL%"
goto MAIN_MENU

:SET_METHOD
cls
echo Choose compression method:
echo    [1] LZMA2  (recommended, best for modern multi-core CPUs)
echo    [2] LZMA   (older standard, poor multi-core scaling)
echo    [3] PPMd   (best for text/log files, poor for binaries)
echo    [4] BZip2  (legacy compatibility)
echo    [0] Back

echo. & set "choice=" & set /p "choice=--> Select method (1-4): "
if "%choice%"=="" goto SET_METHOD
if "%choice%"=="0" goto MAIN_MENU
if "%choice%"=="1" set "METHOD=LZMA2" & goto MAIN_MENU
if "%choice%"=="2" set "METHOD=LZMA" & goto MAIN_MENU
if "%choice%"=="3" set "METHOD=PPMd" & goto MAIN_MENU
if "%choice%"=="4" set "METHOD=BZip2" & goto MAIN_MENU

call :INVALID "(0-4)" & goto SET_METHOD

:SET_DICT
cls & echo Choose dictionary size (-md), or "auto" to let 7-Zip pick based on -mx:
echo    Common values: 64k, 1m, 16m, 32m, 64m, 128m, 256m, 512m, 1024m
echo    Note: RAM usage during compression is roughly 10x dictionary size x threads

echo. & set "choice=" & set /p "choice=--> Enter dictionary size (or auto): "
if "%choice%"=="" goto SET_DICT
set "DICT_SIZE=%choice%"
goto MAIN_MENU

:SET_FASTBYTES
cls & echo Choose fast bytes (-mfb), or "auto" to let 7-Zip pick based on -mx:
echo    Valid range: 5-273 (LZMA/LZMA2). Higher = smaller size, slower compression.

echo. & set "choice=" & set /p "choice=Enter fast bytes value (or 'auto'): "
if not defined choice goto MAIN_MENU
if /i "%choice%"=="auto" (
    set "FAST_BYTES=auto"
    goto MAIN_MENU
)
echo %choice%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid value, must be a number between 5 and 273, or 'auto'
    pause & goto MAIN_MENU
)
if %choice% lss 5 (
    echo Value must be between 5 and 273
    pause & goto MAIN_MENU
)
if %choice% gtr 273 (
    echo Value must be between 5 and 273
    pause & goto MAIN_MENU
)
set "FAST_BYTES=%choice%"
goto MAIN_MENU

:TOGGLE_SOLID
if "%SOLID_MODE%"=="on" (set "SOLID_MODE=off") else (set "SOLID_MODE=on")
goto MAIN_MENU

:SET_MULTITHREAD
cls & echo Choose multithreading (-mmt):
echo    [1] on         - use all available CPU cores/threads
echo    [2] off        - single thread only
echo    [3] Custom N   - restrict to a specific number of threads

echo. & set "choice=" & set /p "choice=--> Select option (1-3): "
if "%choice%"=="1" set "MULTITHREAD=on"
if "%choice%"=="2" set "MULTITHREAD=off"
if "%choice%"=="3" (
    echo. & set "MT_NUM=" & set /p "MT_NUM=Enter number of threads: "
    echo !MT_NUM!| findstr /r "^[0-9][0-9]*$" >nul
    if errorlevel 1 (
        echo Invalid number
        pause & goto MAIN_MENU
    )
    set "MULTITHREAD=!MT_NUM!"
)
goto MAIN_MENU

:SET_PASSWORD
cls & echo Leave blank and press Enter to remove/disable the password
echo. & set "choice=" & set /p "choice=Enter archive password: "
set "ARCHIVE_PASSWORD=%choice%"
goto MAIN_MENU

:TOGGLE_HEADERENC
if "%ARCHIVE_PASSWORD%"=="" (
    echo. & echo Header encryption requires a password to be set first ^(option 7^)
    pause & goto MAIN_MENU
)
if "%HEADER_ENC%"=="1" (set "HEADER_ENC=0") else (set "HEADER_ENC=1")
goto MAIN_MENU

:TOGGLE_DRYRUN
if "%DRY_RUN%"=="1" (set "DRY_RUN=0") else (set "DRY_RUN=1")
goto MAIN_MENU

:TOGGLE_DELETE
if "%DELETE_AFTER_VERIFY%"=="1" (set "DELETE_AFTER_VERIFY=0") else (set "DELETE_AFTER_VERIFY=1")
goto MAIN_MENU

:START_RUN
cls
set "FOLDER_FOUND=0"

:: Scan for any folder
for /d %%D in (*) do (
    set "FOLDER_FOUND=1"
    goto :CHECK_DONE
)

:CHECK_DONE
if "!FOLDER_FOUND!"=="0" (
    echo. & echo No directories found in the current path to compress
) else (
    echo Using: %SEVENZIP_PATH%
    echo Compression level  : -mx=%COMPRESSION_LEVEL%
    echo Method             : -m0=%METHOD%
    echo Dictionary size    : %DICT_SIZE%
    echo Fast bytes         : %FAST_BYTES%
    echo Solid archive      : -ms=%SOLID_MODE%
    echo Multithreading     : -mmt=%MULTITHREAD%
    if "%ARCHIVE_PASSWORD%"=="" (
        echo Password            : ^(none^)
    ) else (
        if "%HEADER_ENC%"=="1" (
            echo Password            : ^(set, header encryption ON^)
        ) else (
            echo Password            : ^(set, header encryption OFF^)
        )
    )
    if "%DRY_RUN%"=="1" echo [DRY RUN MODE - no files will be changed]
    echo. & call :CHOICE "Proceed with these settings?"
    if errorlevel 2 goto MAIN_MENU
    call :BUILD_ARGS
    call :COMPRESS
    call :TEST
)

echo. & echo The operation is done.
pause & goto MAIN_MENU


:: ==============================================================================
:: 7-ZIP COMMAND LINE COMPRESSION DOCUMENTATION
:: ==============================================================================
:: Syntax: "%SEVENZIP_PATH%" a -t7z [switches] "OutputFile.7z" "InputSource\"
::
:: ------------------------------------------------------------------------------
:: COMMAND (a / t)
:: ------------------------------------------------------------------------------
:: The first non-switch argument to 7z selects the operation:
::   a : Add files to archive (creates the archive if it doesn't exist yet).
::   t : Test archive integrity (reads and CRC-checks every entry, writes
::       nothing to disk; used in the :TEST subroutine below).
::   x / e : Extract with / without folder structure (not used here).
::
:: ------------------------------------------------------------------------------
:: ARCHIVE TYPE (-t)
:: ------------------------------------------------------------------------------
:: Selects the archive container format.
::   -t7z : Use the native 7z format (best compression ratio, supports AES-256
::          encryption of both data and file names). This is the only format
::          used in this script.
::
:: ------------------------------------------------------------------------------
:: COMPRESSION LEVEL (-mx)
:: ------------------------------------------------------------------------------
:: Controls the overall trade-off between compression speed and final file size.
::   -mx=0 : Copy mode (No compression, archives instantly).
::   -mx=1 : Fastest (Minimal compression, very low CPU/RAM usage).
::   -mx=3 : Fast (Low compression, quick turnaround).
::   -mx=5 : Normal (Default balanced setting if not specified).
::   -mx=7 : Maximum (High compression, requires capable system resources).
::   -mx=9 : Ultra (Maximum compression, highest CPU/RAM usage).
::
:: ------------------------------------------------------------------------------
:: COMPRESSION METHOD/ALGORITHM (-m0)
:: ------------------------------------------------------------------------------
:: Defines the mathematical algorithm used to analyze and compress data.
::   -m0=LZMA2 : Best for modern multi-core CPUs. Highly optimized (Recommended).
::   -m0=LZMA  : Older standard. High compression but lacks efficient multi-core scaling.
::   -m0=PPMd  : Exceptional for pure text files and system logs; poor for binaries.
::   -m0=BZip2 : Classic UNIX algorithm, mostly used for legacy compatibility.
::
:: ------------------------------------------------------------------------------
:: DICTIONARY SIZE (-md)
:: ------------------------------------------------------------------------------
:: Sets the memory buffer size used to find duplicate data sequences.
::   Available sizes : 64k, 1m, 16m, 32m, 64m, 128m, 256m, 512m, 1024m.
::   Memory Usage    : RAM required during compression is roughly 10x the
::                     dictionary size multiplied by the number of threads.
::   Omission Note   : If omitted, 7-Zip auto-assigns based on -mx level:
::                     (-mx=1 -> 64KB | -mx=5 -> 16MB | -mx=9 -> 64MB).
:: Not set explicitly in this script; left to 7-Zip's automatic selection
:: based on -mx.
::
:: ------------------------------------------------------------------------------
:: FAST BYTES (-mfb)
:: ------------------------------------------------------------------------------
:: Sets the length of byte sequences to check for matching patterns.
::   Range         : 5 to 273 (For LZMA/LZMA2).
::   Impact        : Higher values marginally reduce size but drastically increase
::                   compression time. Lower values compress much faster.
::   Omission Note : If omitted, 7-Zip auto-assigns based on -mx level:
::                   (-mx=1/3/5 -> 32 bytes | -mx=7/9 -> 64 bytes).
:: Not set explicitly in this script; left to 7-Zip's automatic selection.
::
:: ------------------------------------------------------------------------------
:: SOLID ARCHIVE (-ms)
:: ------------------------------------------------------------------------------
:: Determines whether all source files are treated as a single continuous block.
::   -ms=on  : Combines all files into a single stream. Offers the absolute
::             smallest file size, especially for similar or duplicate files.
::             Drawback: Slower to extract or update a single file later.
::   -ms=off : Compresses each file independently. Larger total size, but allows
::             instantaneous extraction/modification of individual files.
:: This script uses -ms=on since each 7z here holds one complete folder that
:: is normally extracted as a whole, not file-by-file.
::
:: ------------------------------------------------------------------------------
:: MULTITHREADING (-mmt)
:: ------------------------------------------------------------------------------
:: Controls processor utilization and thread allocation.
::   -mmt=on  : Uses all available CPU cores and threads for maximum speed.
::   -mmt=off : Uses a single thread (Keeps CPU usage low for background tasks).
::   -mmt=4   : Restricts usage to a specific number of threads (e.g., 4 threads).
::
:: ------------------------------------------------------------------------------
:: PASSWORD PROTECTION (-p)
:: ------------------------------------------------------------------------------
:: Sets a password to encrypt the archive contents.
::   -pMyPassword : Protects the archive using the specified password.
::   -p           : Prompts for a password interactively (console mode only).
::
:: ------------------------------------------------------------------------------
:: HEADER ENCRYPTION (-mhe)
:: ------------------------------------------------------------------------------
:: Encrypts file names and folder structure inside the archive.
::   -mhe=on  : Hides all archive contents until the correct password is entered.
::   -mhe=off : Only file data is encrypted; names remain visible.
:: Only applied when a password is set, since -mhe has no effect (and 7-Zip
:: will warn) without encryption enabled via -p.
::
:: ------------------------------------------------------------------------------
:: PROGRESS / OUTPUT VERBOSITY (-bsp1, -bb1)
:: ------------------------------------------------------------------------------
:: -bsp1 : Redirects the percentage progress indicator to stdout so it is
::         visible in a normal console/batch run (some 7z builds send it
::         elsewhere by default).
:: -bb1  : Sets log-message verbosity to level 1 (shows names of processed
::         files without flooding the console at higher levels like -bb3).
:: Added so long compressions give visible feedback instead of appearing to
:: hang silently until completion.
:: ==============================================================================
:BUILD_ARGS
set "SEVENZIP_ARGS=-t7z -mx=%COMPRESSION_LEVEL% -m0=%METHOD%"
if /i not "%DICT_SIZE%"=="auto" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -md=%DICT_SIZE%"
if /i not "%FAST_BYTES%"=="auto" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -mfb=%FAST_BYTES%"
set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -ms=%SOLID_MODE% -mmt=%MULTITHREAD% -bsp1 -bb1"
if not "%ARCHIVE_PASSWORD%"=="" (
    set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -p"%ARCHIVE_PASSWORD%""
    if "%HEADER_ENC%"=="1" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -mhe=on"
)
goto :eof


:COMPRESS
:: Reset all counters before running compression
set "TOTAL_COUNT=0"
set "SUCCESS_COUNT=0"
set "FAILED_COUNT=0"
set "FAILED_LIST="

for /d %%I in (*) do (
    call :DO_COMPRESS "%%~I"
)

echo. & echo.
echo ==============================================================================
echo                               COMPRESSION SUMMARY
echo ==============================================================================
echo Total folders found         : !TOTAL_COUNT!
echo Successfully compressed     : !SUCCESS_COUNT!
echo Failed to compress          : !FAILED_COUNT!
if !FAILED_COUNT! gtr 0 echo Failed folders             : !FAILED_LIST!
echo ==============================================================================
goto :eof


:DO_COMPRESS
set "FOLDER_NAME=%~1"
set /a TOTAL_COUNT+=1
echo.

if exist "%FOLDER_NAME%.7z" (
    if "%DRY_RUN%"=="1" (
        echo [DRY RUN] Would remove existing archive: "%FOLDER_NAME%.7z"
    ) else (
        echo Removing existing archive: "%FOLDER_NAME%.7z"
        del /f /q "%FOLDER_NAME%.7z"
    )
)

if exist "%FOLDER_NAME%.7z" if not "%DRY_RUN%"=="1" (
    echo [ERROR] Failed to delete existing archive "%FOLDER_NAME%.7z"
    pause & exit /b 1
)

if "%DRY_RUN%"=="1" (
    echo [DRY RUN] Would compress: "%FOLDER_NAME%" -^> "%FOLDER_NAME%.7z" ^(%SEVENZIP_ARGS%^)
    set /a SUCCESS_COUNT+=1
) else (
    echo. & echo Compressing: "%FOLDER_NAME%"
    "%SEVENZIP_PATH%" a %SEVENZIP_ARGS% "%FOLDER_NAME%.7z" "%FOLDER_NAME%"

    if errorlevel 1 (
        echo [ERROR] Failed to compress "%FOLDER_NAME%"
        set /a FAILED_COUNT+=1
        set "FAILED_LIST=!FAILED_LIST!; %FOLDER_NAME%"
    ) else (
        set /a SUCCESS_COUNT+=1
    )
)
goto :eof


:TEST
if "%DRY_RUN%"=="1" (
    echo. & echo [DRY RUN] Skipping verification/removal step entirely
    goto :eof
)

if "%DELETE_AFTER_VERIFY%"=="0" (
    echo. & echo Delete-source-on-success is OFF. Skipping verification/removal step.
    goto :eof
)

echo. & echo !SUCCESS_COUNT! archive(s) were created successfully out of !TOTAL_COUNT! folder(s) found
call :CHOICE "Verify all archives and PERMANENTLY delete their source folders on success?"
if errorlevel 2 goto :eof

:: Reset verification counters
set "VERIFY_TOTAL=0"
set "VERIFY_SUCCESS=0"
set "VERIFY_FAILED=0"
set "REMOVE_SUCCESS=0"
set "REMOVE_FAILED=0"
set "VERIFY_FAILED_LIST="
set "REMOVE_FAILED_LIST="

for /d %%I in (*) do (
    call :DO_TEST "%%~I"
)

echo. & echo.
echo ==============================================================================
echo                               VERIFICATION SUMMARY
echo ==============================================================================
echo Archives tested             : !VERIFY_TOTAL!
echo Verification succeeded      : !VERIFY_SUCCESS!
echo Verification failed         : !VERIFY_FAILED!
if !VERIFY_FAILED! gtr 0 echo Failed verification for     : !VERIFY_FAILED_LIST!
echo Folders removed             : !REMOVE_SUCCESS!
echo Folders failed to remove    : !REMOVE_FAILED!
if !REMOVE_FAILED! gtr 0 echo Failed removal for          : !REMOVE_FAILED_LIST!
echo ==============================================================================
goto :eof


:DO_TEST
set "FOLDER_NAME=%~1"
if exist "%FOLDER_NAME%.7z" (
    set /a VERIFY_TOTAL+=1
    echo. & echo Testing: "%FOLDER_NAME%.7z"
    if "%ARCHIVE_PASSWORD%"=="" (
        "%SEVENZIP_PATH%" t "%FOLDER_NAME%.7z"
    ) else (
        "%SEVENZIP_PATH%" t -p"%ARCHIVE_PASSWORD%" "%FOLDER_NAME%.7z"
    )

    if errorlevel 1 (
        echo [ERROR] Verification failed - skipping removal of "%FOLDER_NAME%"
        set /a VERIFY_FAILED+=1
        set "VERIFY_FAILED_LIST=!VERIFY_FAILED_LIST!; %FOLDER_NAME%"
    ) else (
        echo [SUCCESS] Verification success - Removing Folder: "%FOLDER_NAME%"
        set /a VERIFY_SUCCESS+=1
        rd /s /q "%FOLDER_NAME%"
        if exist "%FOLDER_NAME%\" (
            echo [ERROR] Failed to remove Folder: "%FOLDER_NAME%"
            set /a REMOVE_FAILED+=1
            set "REMOVE_FAILED_LIST=!REMOVE_FAILED_LIST!; %FOLDER_NAME%"
        ) else (
            set /a REMOVE_SUCCESS+=1
        )
    )
)
goto :eof

:CHOICE
choice /C YN /N /M "%~1 (Y/N): "
exit /b

:INVALID
echo. & echo [ERROR] Invalid selection. Please choose a valid option between %~1
pause
exit /b
