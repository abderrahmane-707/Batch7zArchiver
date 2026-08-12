@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "SEVENZIP_PATH="
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

:: Quickly scan for at least one directory
for /d %%D in (*) do (
    set "FOLDER_FOUND=1"
	goto CHECK_DONE
)

:CHECK_DONE
if "!FOLDER_FOUND!"=="0" (
    echo. & echo No directories found in the current path to compress
) else (
    echo Using: %SEVENZIP_PATH%
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
:: 1. COMPRESSION LEVEL (-mx)
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
:: 2. COMPRESSION METHOD/ALGORITHM (-m0)
:: ------------------------------------------------------------------------------
:: Defines the mathematical algorithm used to analyze and compress data.
::   -m0=LZMA2 : Best for modern multi-core CPUs. Highly optimized (Recommended).
::   -m0=LZMA  : Older standard. High compression but lacks efficient multi-core scaling.
::   -m0=PPMd  : Exceptional for pure text files and system logs; poor for binaries.
::   -m0=BZip2 : Classic UNIX algorithm, mostly used for legacy compatibility.
::
:: ------------------------------------------------------------------------------
:: 3. DICTIONARY SIZE (-md)
:: ------------------------------------------------------------------------------
:: Sets the memory buffer size used to find duplicate data sequences.
::   Available sizes : 64k, 1m, 16m, 32m, 64m, 128m, 256m, 512m, 1024m.
::   Memory Usage    : RAM required during compression is roughly 10x the 
::                     dictionary size multiplied by the number of threads.
::   Omission Note   : If omitted, 7-Zip auto-assigns based on -mx level:
::                     (-mx=1 -> 64KB | -mx=5 -> 16MB | -mx=9 -> 64MB).
::
:: ------------------------------------------------------------------------------
:: 4. FAST BYTES (-mfb)
:: ------------------------------------------------------------------------------
:: Sets the length of byte sequences to check for matching patterns.
::   Range         : 5 to 273 (For LZMA/LZMA2).
::   Impact        : Higher values marginally reduce size but drastically increase
::                   compression time. Lower values compress much faster.
::   Omission Note : If omitted, 7-Zip auto-assigns based on -mx level:
::                   (-mx=1/3/5 -> 32 bytes | -mx=7/9 -> 64 bytes).
::
:: ------------------------------------------------------------------------------
:: 5. SOLID ARCHIVE (-ms)
:: ------------------------------------------------------------------------------
:: Determines whether all source files are treated as a single continuous block.
::   -ms=on  : Combines all files into a single stream. Offers the absolute 
::             smallest file size, especially for similar or duplicate files.
::             Drawback: Slower to extract or update a single file later.
::   -ms=off : Compresses each file independently. Larger total size, but allows
::             instantaneous extraction/modification of individual files.
::
:: ------------------------------------------------------------------------------
:: 6. MULTITHREADING (-mmt)
:: ------------------------------------------------------------------------------
:: Controls processor utilization and thread allocation.
::   -mmt=on  : Uses all available CPU cores and threads for maximum speed.
::   -mmt=off : Uses a single thread (Keeps CPU usage low for background tasks).
::   -mmt=4   : Restricts usage to a specific number of threads (e.g., 4 threads).
::
:: ------------------------------------------------------------------------------
:: 7. PASSWORD PROTECTION (-p)
:: ------------------------------------------------------------------------------
:: Sets a password to encrypt the archive contents.
::   -pMyPassword : Protects the archive using the specified password.
::   -p           : Prompts for a password interactively (console mode only).
::
:: ------------------------------------------------------------------------------
:: 8. HEADER ENCRYPTION (-mhe)
:: ------------------------------------------------------------------------------
:: Encrypts file names and folder structure inside the archive.
::   -mhe=on  : Hides all archive contents until the correct password is entered.
::   -mhe=off : Only file data is encrypted; names remain visible.
:: ==============================================================================


:: ----------------------------------------------------------------< FUNCTIONS >----------------------------------------------------------------
:COMPRESS
:: Compress all folders
for /d %%i in (*) do (
    set /a TOTAL_COUNT+=1
    echo.
    if exist "%%~ni.7z" (
        echo Removing existing archive: "%%~ni.7z"
        del /f /q "%%~ni.7z"
    )
    if exist "%%~ni.7z" (
        echo [ERROR] Failed to delete existing archive
        pause & exit /b 1
    )
    echo. & echo Compressing: "%%i"
    "%SEVENZIP_PATH%" a -t7z -mx=9 -m0=LZMA2 -ms=on -mmt=on "%%~ni.7z" "%%i\"

    if !errorlevel! neq 0 (
	    echo [ERROR] Failed to compress
		set /a FAILED_COUNT+=1
		set "FAILED_LIST=!FAILED_LIST! %%i"
	) else (
	    set /a SUCCESS_COUNT+=1
	)
)

echo. & echo.
echo ==============================================================================
echo                              COMPRESSION SUMMARY
echo ==============================================================================
echo Total folders found        : !TOTAL_COUNT!
echo Successfully compressed    : !SUCCESS_COUNT!
echo Failed to compress         : !FAILED_COUNT!
if !FAILED_COUNT! gtr 0 echo Failed folders             :!FAILED_LIST!
echo ==============================================================================
goto :eof

:TEST
echo. & choice /C YN /N /M "Verify all archives and remove source folders? (Y/N): "
if errorlevel 2 goto :eof

set "VERIFY_TOTAL=0"
set "VERIFY_SUCCESS=0"
set "VERIFY_FAILED=0"
set "REMOVE_SUCCESS=0"
set "REMOVE_FAILED=0"
set "VERIFY_FAILED_LIST="
set "REMOVE_FAILED_LIST="

for /d %%i in (*) do (
    if exist "%%~ni.7z" (
        set /a VERIFY_TOTAL+=1
        echo. & echo Testing: "%%~ni.7z"

        "%SEVENZIP_PATH%" -p123 t "%%~ni.7z"

        if !errorlevel! neq 0 (
            echo [ERROR] Verification failed - skipping removing
            set /a VERIFY_FAILED+=1
            set "VERIFY_FAILED_LIST=!VERIFY_FAILED_LIST! %%i"
        ) else (
		    echo [SUCCESS] Verification success - Removing Folder
            set /a VERIFY_SUCCESS+=1
            rd /s /q "%%i"
            
            :: Check if the directory still exists to confirm deletion failure
            if exist "%%i\" (
                echo [ERROR] Failed to remove Folder: "%%i"
                set /a REMOVE_FAILED+=1
                set "REMOVE_FAILED_LIST=!REMOVE_FAILED_LIST! %%i"
            ) else (
                set /a REMOVE_SUCCESS+=1
            )
        )
    )
)

echo. & echo.
echo ==============================================================================
echo                             VERIFICATION SUMMARY
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
