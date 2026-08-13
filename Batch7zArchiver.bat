@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: Maximum compression
set "COMPRESSION_LEVEL=9"

:: Leave empty for unencrypted archives
set "ARCHIVE_PASSWORD="

:: When set to 1, the script only prints what it would compress/delete
set "DRY_RUN=0"

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
    echo 7-Zip not found
    pause & exit /b 1
)

:: Scan for any folder
for /d %%D in (*) do (
    set "FOLDER_FOUND=1"
    goto CHECK_DONE
)

:CHECK_DONE
if "!FOLDER_FOUND!"=="0" (
    echo. & echo No directories found in the current path to compress
) else (
    echo Using: %SEVENZIP_PATH%
    echo Compression level: -mx=%COMPRESSION_LEVEL%
    if "%DRY_RUN%"=="1" echo [DRY RUN MODE - no files will be changed]
    call :COMPRESS
    call :TEST
)

echo. & echo The operation is done.
pause & exit /b



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

:COMPRESS
for /d %%i in (*) do (
    set /a TOTAL_COUNT+=1
    echo.

    if exist "%%i.7z" (
        if "%DRY_RUN%"=="1" (
            echo [DRY RUN] Would remove existing archive: "%%i.7z"
        ) else (
            echo Removing existing archive: "%%i.7z"
            del /f /q "%%i.7z"
        )
    )

    if exist "%%i.7z" if not "%DRY_RUN%"=="1" (
        echo [ERROR] Failed to delete existing archive
        pause & exit /b 1
    )

    if "%DRY_RUN%"=="1" (
        echo [DRY RUN] Would compress: "%%i" -^> "%%i.7z"
        set /a SUCCESS_COUNT+=1
    ) else (
        echo. & echo Compressing: "%%i"
        if "%ARCHIVE_PASSWORD%"=="" (
            "%SEVENZIP_PATH%" a -t7z -mx=%COMPRESSION_LEVEL% -m0=LZMA2 -ms=on -mmt=on -bsp1 -bb1 "%%i.7z" "%%i"
        ) else (
            "%SEVENZIP_PATH%" a -t7z -mx=%COMPRESSION_LEVEL% -m0=LZMA2 -ms=on -mmt=on -bsp1 -bb1 -p%ARCHIVE_PASSWORD% -mhe=on "%%i.7z" "%%i"
        )

        if !errorlevel! neq 0 (
            echo [ERROR] Failed to compress
            set /a FAILED_COUNT+=1
            set "FAILED_LIST=!FAILED_LIST!;%%i"
        ) else (
            set /a SUCCESS_COUNT+=1
        )
    )
)

echo. & echo.
echo ==============================================================================
echo                               COMPRESSION SUMMARY
echo ==============================================================================
echo Total folders found         : !TOTAL_COUNT!
echo Successfully compressed     : !SUCCESS_COUNT!
echo Failed to compress          : !FAILED_COUNT!
if !FAILED_COUNT! gtr 0 echo Failed folders             :!FAILED_LIST!
echo ==============================================================================
goto :eof

:TEST
if "%DRY_RUN%"=="1" (
    echo. & echo [DRY RUN] Skipping verification/removal step entirely
    goto :eof
)

echo. & echo !SUCCESS_COUNT! archive(s) were created successfully out of !TOTAL_COUNT! folder(s) found.
choice /C YN /N /M "Verify all archives and PERMANENTLY delete their source folders on success? (Y/N): "
if errorlevel 2 goto :eof

set "VERIFY_TOTAL=0"
set "VERIFY_SUCCESS=0"
set "VERIFY_FAILED=0"
set "REMOVE_SUCCESS=0"
set "REMOVE_FAILED=0"
set "VERIFY_FAILED_LIST="
set "REMOVE_FAILED_LIST="

for /d %%i in (*) do (
    if exist "%%i.7z" (
        set /a VERIFY_TOTAL+=1
        echo. & echo Testing: "%%i.7z"
        if "%ARCHIVE_PASSWORD%"=="" (
            "%SEVENZIP_PATH%" t "%%i.7z"
        ) else (
            "%SEVENZIP_PATH%" t -p%ARCHIVE_PASSWORD% "%%i.7z"
        )

        if !errorlevel! neq 0 (
            echo [ERROR] Verification failed - skipping removal
            set /a VERIFY_FAILED+=1
            set "VERIFY_FAILED_LIST=!VERIFY_FAILED_LIST!;%%i"
        ) else (
            echo [SUCCESS] Verification success - Removing Folder
            set /a VERIFY_SUCCESS+=1
            rd /s /q "%%i"
            if exist "%%i\" (
                echo [ERROR] Failed to remove Folder: "%%i"
                set /a REMOVE_FAILED+=1
                set "REMOVE_FAILED_LIST=!REMOVE_FAILED_LIST!;%%i"
            ) else (
                set /a REMOVE_SUCCESS+=1
            )
        )
    )
)

echo. & echo.
echo ==============================================================================
echo                               VERIFICATION SUMMARY
echo ==============================================================================
echo Archives tested             : !VERIFY_TOTAL!
echo Verification succeeded      : !VERIFY_SUCCESS!
echo Verification failed         : !VERIFY_FAILED!
if !VERIFY_FAILED! gtr 0 echo Failed verification for     :!VERIFY_FAILED_LIST!
echo Folders removed             : !REMOVE_SUCCESS!
echo Folders failed to remove    : !REMOVE_FAILED!
if !REMOVE_FAILED! gtr 0 echo Failed removal for          :!REMOVE_FAILED_LIST!
echo ==============================================================================
goto :eof
