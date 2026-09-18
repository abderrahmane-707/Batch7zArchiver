@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

where 7z >nul 2>nul
if %errorlevel% equ 0 (
    set "SEVENZIP_PATH=7z"
) else if exist "%PROGRAMFILES%\7-Zip\7z.exe" (
    set "SEVENZIP_PATH=%PROGRAMFILES%\7-Zip\7z.exe"
) else if exist "%PROGRAMFILES(x86)%\7-Zip\7z.exe" (
    set "SEVENZIP_PATH=%PROGRAMFILES(x86)%\7-Zip\7z.exe"
) else (
    echo 7-Zip not found in system PATH or standard directories
    pause & exit /b 1
)

call :INIT

:MAIN_MENU
cls
echo ==============================================================================
echo                          7-ZIP FOLDER COMPRESSOR
echo ==============================================================================
echo   Using                               : %SEVENZIP_PATH%
echo   Working directory                   : %CD%
echo ------------------------------------------------------------------------------
echo    [1]  Compression level (-mx)        : %COMPRESSION_LEVEL%
echo    [2]  Compression method (-m0)       : %METHOD%
echo    [3]  Dictionary size (-md)          : %DICT_SIZE%
echo    [4]  Fast bytes (-mfb)              : %FAST_BYTES%
echo    [5]  Solid archive (-ms)            : %SOLID_MODE%
echo    [6]  Multithreading (-mmt)          : %MULTITHREAD%
if "%ARCHIVE_PASSWORD%"=="" (
    echo    [7]  Archive password ^(-p^)          : OFF
) else (
    echo    [7]  Archive password ^(-p^)          : ON
)
if "%ARCHIVE_PASSWORD%"=="" (
    echo    [8]  Header encryption ^(-mhe^)       : N/A ^(requires password^)
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

echo. & set "choice=" & set /p "choice=--> Select option(s) and press [S] to Start: "
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
cls
set "NEW_LEVEL="
call :GET_MAX_LEVEL

set /p "NEW_LEVEL=Enter compression level for %METHOD% (0-%MAX_ALLOWED%): "

echo %NEW_LEVEL%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo. & echo Invalid value, must be a whole number between 0 and %MAX_ALLOWED%
    pause & goto MAIN_MENU
)

if %NEW_LEVEL% gtr %MAX_ALLOWED% (
    echo. & echo Error: Compression level cannot exceed %MAX_ALLOWED% for %METHOD%
    pause & goto MAIN_MENU
)

set "COMPRESSION_LEVEL=%NEW_LEVEL%"
goto MAIN_MENU

:SET_METHOD
cls & echo Choose compression method:
echo    [1]  LZMA2      (recommended, best for modern multi-core CPUs)
echo    [2]  LZMA       (older standard, poor multi-core scaling)
echo    [3]  PPMd       (best for text/log files, poor for binaries)
echo    [4]  BZip2      (legacy compatibility)
echo    [5]  Deflate    (zip-compatible, low ratio, very fast)
echo    [6]  Deflate64  (zip-compatible extension of Deflate)
echo    [7]  Copy       (no compression, store only)
echo    [8]  Brotli     (good ratio, fast decompression)
echo    [9]  Lizard     (very fast decompression)
echo    [10] Fast LZMA2 (LZMA2 quality, 20-100%% faster on multi-core)
echo    [11] Zstandard  (zstd - excellent speed/ratio balance, supports -mx1..22)
echo    [12] LZ4        (extremely fast, low ratio)
echo    [13] LZ5        (LZ4-derived, better ratio, still fast)
echo    [0]  Back

echo. & set "choice=" & set /p "choice=--> Select method (1-13): "
if "%choice%"=="" goto SET_METHOD
if "%choice%"=="0" goto MAIN_MENU
if "%choice%"=="1" set "METHOD=LZMA2" & goto METHOD_CHANGED
if "%choice%"=="2" set "METHOD=LZMA" & goto METHOD_CHANGED
if "%choice%"=="3" set "METHOD=PPMd" & goto METHOD_CHANGED
if "%choice%"=="4" set "METHOD=BZip2" & goto METHOD_CHANGED
if "%choice%"=="5" set "METHOD=Deflate" & goto METHOD_CHANGED
if "%choice%"=="6" set "METHOD=Deflate64" & goto METHOD_CHANGED
if "%choice%"=="7" set "METHOD=Copy" & goto METHOD_CHANGED
if "%choice%"=="8" set "METHOD=Brotli" & goto METHOD_CHANGED
if "%choice%"=="9" set "METHOD=Lizard" & goto METHOD_CHANGED
if "%choice%"=="10" set "METHOD=flzma2" & goto METHOD_CHANGED
if "%choice%"=="11" set "METHOD=zstd" & goto METHOD_CHANGED
if "%choice%"=="12" set "METHOD=lz4" & goto METHOD_CHANGED
if "%choice%"=="13" set "METHOD=lz5" & goto METHOD_CHANGED

call :INVALID "(0-13)" & goto SET_METHOD

:METHOD_CHANGED
call :METHOD_SANITY
goto MAIN_MENU

:SET_DICT
cls & echo Choose dictionary size (-md), or "Auto" to let 7-Zip pick based on -mx:
echo    Common values: 64k, 1m, 16m, 32m, 64m, 128m, 256m, 512m, 1024m
echo    Note: RAM usage during compression is roughly 10x dictionary size x threads
echo    Note: -md has no effect on Copy, Deflate, Deflate64, LZ4, LZ5, Zstandard

echo. & set "choice=" & set /p "choice=--> Enter dictionary size (or Auto): "
if "%choice%"=="" goto SET_DICT
if /i "%choice%"=="Auto" (
    set "DICT_SIZE=Auto"
    goto MAIN_MENU
)

call :IS_DICT_SUPPORTED
if "%DICT_SUPPORTED%"=="0" (
    echo. & echo Error: -md is not supported/meaningful for method %METHOD%
    pause & goto MAIN_MENU
)

echo %choice%| findstr /r /i "^[0-9][0-9]*[kmg]$" >nul
if errorlevel 1 (
    echo. & echo Invalid value. Use a number followed by k, m or g ^(e.g. 64m^), or "Auto"
    pause & goto MAIN_MENU
)

set "DICT_SIZE=%choice%"
goto MAIN_MENU

:SET_FASTBYTES
cls & echo Choose fast bytes (-mfb), or "Auto" to let 7-Zip pick based on -mx:
echo    Valid range: 5-273 (LZMA/LZMA2/Fast LZMA2 only). Higher = smaller size, slower compression.
echo    Note: -mfb has no effect on Copy, Deflate, Deflate64, PPMd, BZip2, Brotli, Lizard, LZ4, LZ5, Zstandard

echo. & set "choice=" & set /p "choice=Enter fast bytes value (or 'Auto'): "
if not defined choice goto MAIN_MENU
if /i "%choice%"=="Auto" (
    set "FAST_BYTES=Auto"
    goto MAIN_MENU
)

call :IS_FB_SUPPORTED
if "%FB_SUPPORTED%"=="0" (
    echo. & echo Error: -mfb is not supported/meaningful for method %METHOD%
    pause & goto MAIN_MENU
)

echo %choice%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo. & echo Invalid value, must be a number between 5 and 273, or 'Auto'
    pause & goto MAIN_MENU
)
if %choice% lss 5 (
    echo. & echo Value must be between 5 and 273
    pause & goto MAIN_MENU
)
if %choice% gtr 273 (
    echo. & echo Value must be between 5 and 273
    pause & goto MAIN_MENU
)
set "FAST_BYTES=%choice%"
goto MAIN_MENU

:TOGGLE_SOLID
if "%SOLID_MODE%"=="ON" (set "SOLID_MODE=OFF") else (set "SOLID_MODE=ON")
goto MAIN_MENU

:SET_MULTITHREAD
cls & echo Choose multithreading (-mmt):
echo    [1] ON         - use all available CPU cores/threads
echo    [2] OFF        - single thread only
echo    [3] Custom N   - restrict to a specific number of threads

echo. & set "choice=" & set /p "choice=--> Select option (1-3): "
if "%choice%"=="1" set "MULTITHREAD=ON" & goto MAIN_MENU
if "%choice%"=="2" set "MULTITHREAD=OFF" & goto MAIN_MENU
if "%choice%"=="3" (
    echo. & set "MT_NUM=" & set /p "MT_NUM=Enter number of threads: "
    echo !MT_NUM!| findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 (
        echo. & echo Invalid number. Must be a whole number of 1 or more
        pause & goto MAIN_MENU
    )
    set "MULTITHREAD=!MT_NUM!"
    goto MAIN_MENU
)
call :INVALID "(1-3)" & goto SET_MULTITHREAD

:SET_PASSWORD
cls & echo Leave blank and press Enter to disable the password
echo. & set "choice=" & set /p "choice=Enter archive password: "

if "%choice%"=="" (
    set "ARCHIVE_PASSWORD="
    set "HEADER_ENC=1"
    goto MAIN_MENU
)

echo %choice%| findstr /c:"\"" >nul
if not errorlevel 1 (
    echo. & echo Error: password cannot contain a double-quote character ^(^"^)
    pause & goto MAIN_MENU
)

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

:: Re-validate settings one last time before running, in case anything is inconsistent
call :METHOD_SANITY

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
        echo Password            : ^(OFF^)
    ) else (
        if "%HEADER_ENC%"=="1" (
            echo Password            : ^(ON, header encryption ON^)
        ) else (
            echo Password            : ^(ON, header encryption OFF^)
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
:: 7-ZIP FOLDER COMPRESSOR - PARAMETER DOCUMENTATION
:: ==============================================================================
:: Companion reference for 7zip_compressor.bat
:: Syntax used internally: "%SEVENZIP_PATH%" a -t7z [switches] "OutputFile.7z" "InputSource"
::
:: ------------------------------------------------------------------------------
:: COMMAND (a / t)
:: ------------------------------------------------------------------------------
:: The first non-switch argument to 7z selects the operation:
::   a : Add files to archive (creates the archive if it doesn't exist yet).
::   t : Test archive integrity (reads and CRC-checks every entry, writes
::       nothing to disk; used in the :TEST subroutine).
::   x / e : Extract with / without folder structure (not used in this script).
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
:: The valid range depends on the selected method (-m0) and is enforced by the
:: :GET_MAX_LEVEL / :METHOD_SANITY subroutines, which clamp or reject any level
:: that is out of range for the current method:
::
::   -mx=0        : Copy mode (no compression, archives instantly). This is
::                  also the ONLY level Copy supports (max = 0).
::   -mx=1        : Fastest (minimal compression, very low CPU/RAM usage).
::   -mx=3        : Fast (low compression, quick turnaround).
::   -mx=5        : Normal (balanced setting).
::   -mx=7        : Maximum (high compression, requires capable system resources).
::   -mx=9        : Ultra - the highest level for: LZMA2, LZMA, PPMd, BZip2,
::                  Deflate, Deflate64, Lizard, LZ4 and LZ5.
::   -mx=11       : Highest level supported by Brotli.
::   -mx=1..22    : Full range supported by Zstandard (zstd) and Fast LZMA2
::                  (flzma2), which use a wider scale than the classic 0-9 one.
::
:: If you switch methods and the currently set level no longer fits the new
:: method's maximum, the script automatically lowers it and prints a notice
:: instead of silently sending an invalid value to 7z.
::
:: ------------------------------------------------------------------------------
:: COMPRESSION METHOD/ALGORITHM (-m0)
:: ------------------------------------------------------------------------------
:: Defines the algorithm used to analyze and compress data. All 13 options
:: below are selectable from menu option [2]:
::
::   -m0=LZMA2     : Best for modern multi-core CPUs. Highly optimized (recommended).
::   -m0=LZMA      : Older standard. High compression but poor multi-core scaling.
::   -m0=PPMd      : Exceptional for pure text files and system logs; poor for binaries.
::   -m0=BZip2     : Classic UNIX algorithm, mostly used for legacy compatibility.
::   -m0=Deflate   : Zip-compatible, low ratio, very fast.
::   -m0=Deflate64 : Zip-compatible extension of Deflate with a larger window.
::   -m0=Copy      : No compression at all, just stores the data.
::   -m0=Brotli    : Good ratio, notably fast decompression.
::   -m0=Lizard    : Tuned for very fast decompression.
::   -m0=flzma2    : Fast LZMA2 - same quality as LZMA2, 20-100% faster on multi-core CPUs.
::   -m0=zstd      : Zstandard - excellent speed/ratio balance, wide -mx range (1-22).
::   -m0=lz4       : Extremely fast, low compression ratio.
::   -m0=lz5       : LZ4-derived, better ratio while staying fast.
::
:: ------------------------------------------------------------------------------
:: DICTIONARY SIZE (-md)
:: ------------------------------------------------------------------------------
:: Sets the memory buffer size used to find duplicate data sequences.
::   Available sizes : e.g. 64k, 1m, 16m, 32m, 64m, 128m, 256m, 512m, 1024m.
::   Memory usage    : RAM required during compression is roughly 10x the
::                     dictionary size multiplied by the number of threads.
::   Auto behavior   : If left as "Auto", 7-Zip assigns it based on -mx
::                     (e.g. -mx=1 -> 64KB | -mx=5 -> 16MB | -mx=9 -> 64MB).
::
:: Set via menu option [3]. The script only accepts "Auto" or a number followed
:: by k/m/g (e.g. 64m), and ONLY when the current method actually uses -md.
:: It is rejected outright if you try to set it manually while an unsupported
:: method is active, and automatically reset to Auto (with an on-screen notice)
:: if you later switch to one of these methods:
::   Copy, Deflate, Deflate64, LZ4, LZ5, Zstandard (zstd)
:: None of these use a 7z-style search dictionary.
::
:: ------------------------------------------------------------------------------
:: FAST BYTES (-mfb)
:: ------------------------------------------------------------------------------
:: Sets the length of byte sequences to check for matching patterns.
::   Range   : 5 to 273.
::   Impact  : Higher values marginally reduce size but drastically increase
::             compression time. Lower values compress much faster.
::   Auto behavior : If left as "Auto", 7-Zip assigns it based on -mx
::                   (-mx=1/3/5 -> 32 bytes | -mx=7/9 -> 64 bytes).
::
:: Set via menu option [4]. Only meaningful for these methods:
::   LZMA, LZMA2, flzma2 (Fast LZMA2)
:: The script rejects a manual value for every other method, and automatically
:: resets it to Auto (with a notice) if you switch away from one of these three.
::
:: ------------------------------------------------------------------------------
:: SOLID ARCHIVE (-ms)
:: ------------------------------------------------------------------------------
:: Determines whether all source files are treated as a single continuous block.
::   -ms=on  : Combines all files into a single stream. Smallest possible file
::             size, especially for similar or duplicate files. Slower to
::             extract or update a single file later.
::   -ms=off : Compresses each file independently. Larger total size, but
::             allows instantaneous extraction/modification of individual files.
::
:: Defaults to -ms=on since each 7z archive here holds one complete folder
:: that is normally extracted as a whole, not file-by-file. Toggle via menu
:: option [5].
::
:: ------------------------------------------------------------------------------
:: MULTITHREADING (-mmt)
:: ------------------------------------------------------------------------------
:: Controls processor utilization and thread allocation.
::   -mmt=on  : Uses all available CPU cores/threads for maximum speed.
::   -mmt=off : Uses a single thread (keeps CPU usage low for background tasks).
::   -mmt=N   : Restricts usage to a specific number of threads.
::
:: Set via menu option [6]. A custom N is validated to be a whole number of 1
:: or more - 0 or a blank entry is rejected.
::
:: ------------------------------------------------------------------------------
:: PASSWORD PROTECTION (-p)
:: ------------------------------------------------------------------------------
:: Sets a password to encrypt the archive contents.
::   -pMyPassword : Protects the archive using the specified password.
::   -p           : Prompts for a password interactively (console mode only,
::                  not used by this script - the password is always supplied
::                  inline).
::
:: Set via menu option [7]. A password containing a double-quote character (")
:: is rejected, since it would break the quoted -p"..." switch built by
:: :BUILD_ARGS. Leaving the field blank disables the password entirely.
::
:: ------------------------------------------------------------------------------
:: HEADER ENCRYPTION (-mhe)
:: ------------------------------------------------------------------------------
:: Encrypts file names and folder structure inside the archive.
::   -mhe=on  : Hides all archive contents (including names) until the correct
::              password is entered.
::   -mhe=off : Only file data is encrypted; names remain visible.
::
:: Only applied when a password is set - menu option [8] shows as "N/A" and is
:: locked until a password is configured via option [7], since -mhe has no
:: effect without -p.
::
:: ------------------------------------------------------------------------------
:: PROGRESS / OUTPUT VERBOSITY (-bsp1, -bb1)
:: ------------------------------------------------------------------------------
::   -bsp1 : Redirects the percentage progress indicator to stdout so it is
::           visible in a normal console/batch run (some 7z builds send it
::           elsewhere by default).
::   -bb1  : Sets log-message verbosity to level 1 (shows names of processed
::           files without flooding the console at higher levels like -bb3).
::
:: Added so long compressions give visible feedback instead of appearing to
:: hang silently until completion.
::
:: ==============================================================================
:: INPUT VALIDATION SUMMARY (added on top of the base 7-Zip switches above)
:: ==============================================================================
:: The script actively prevents inconsistent/invalid combinations instead of
:: passing them straight to 7z:
::
::   - Compression level (-mx) is clamped to the current method's real maximum
::     (0 for Copy, 9 for most classic methods, 11 for Brotli, 22 for
::     zstd/flzma2), both when you change the level directly and whenever you
::     change the method afterwards.
::   - Dictionary size (-md) can only be set for methods that use it, and is
::     validated to be "Auto" or a number + k/m/g suffix.
::   - Fast bytes (-mfb) can only be set for LZMA/LZMA2/flzma2, validated to be
::     "Auto" or a whole number between 5 and 273.
::   - Multithreading (-mmt) custom values must be a whole number >= 1.
::   - Archive passwords cannot contain a double-quote character.
::   - All of the above are re-checked automatically right before compression
::     starts (:METHOD_SANITY called from :START_RUN), so switching options in
::     any order can never leave the script about to run with an invalid
::     combination.
:: ==============================================================================
:INIT
:: Default settings
set "METHOD=zstd"
set "COMPRESSION_LEVEL=19"
set "DICT_SIZE=Auto"
set "FAST_BYTES=Auto"
set "SOLID_MODE=ON"
set "MULTITHREAD=ON"
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

:: Make sure the defaults above are actually consistent with each other
call :METHOD_SANITY
exit /b

:GET_MAX_LEVEL
:: Sets MAX_ALLOWED to the highest -mx value valid for the current %METHOD%
set "MAX_ALLOWED=9"
if /i "%METHOD%"=="zstd"   set "MAX_ALLOWED=22"
if /i "%METHOD%"=="flzma2" set "MAX_ALLOWED=22"
if /i "%METHOD%"=="Brotli" set "MAX_ALLOWED=11"
if /i "%METHOD%"=="Copy"   set "MAX_ALLOWED=0"
exit /b

:IS_DICT_SUPPORTED
:: Sets DICT_SUPPORTED to 0/1 depending on whether -md means anything for %METHOD%
set "DICT_SUPPORTED=1"
if /i "%METHOD%"=="Copy"      set "DICT_SUPPORTED=0"
if /i "%METHOD%"=="Deflate"   set "DICT_SUPPORTED=0"
if /i "%METHOD%"=="Deflate64" set "DICT_SUPPORTED=0"
if /i "%METHOD%"=="lz4"       set "DICT_SUPPORTED=0"
if /i "%METHOD%"=="lz5"       set "DICT_SUPPORTED=0"
if /i "%METHOD%"=="zstd"      set "DICT_SUPPORTED=0"
exit /b

:IS_FB_SUPPORTED
:: Sets FB_SUPPORTED to 0/1 depending on whether -mfb means anything for %METHOD%
set "FB_SUPPORTED=0"
if /i "%METHOD%"=="LZMA2"  set "FB_SUPPORTED=1"
if /i "%METHOD%"=="LZMA"   set "FB_SUPPORTED=1"
if /i "%METHOD%"=="flzma2" set "FB_SUPPORTED=1"
exit /b

:CHECK_METHOD_SUPPORT
set "METHOD_SUPPORTED=1"
set "NEEDS_TEST=0"
if /i "%METHOD%"=="Brotli" set "NEEDS_TEST=1"
if /i "%METHOD%"=="Lizard" set "NEEDS_TEST=1"
if /i "%METHOD%"=="flzma2" set "NEEDS_TEST=1"
if /i "%METHOD%"=="zstd"   set "NEEDS_TEST=1"
if /i "%METHOD%"=="lz4"    set "NEEDS_TEST=1"
if /i "%METHOD%"=="lz5"    set "NEEDS_TEST=1"

:: Classic/built-in methods never need testing - skip immediately
if "%NEEDS_TEST%"=="0" exit /b

:: Re-use a cached result if we already probed this method this session
if defined SUPPORT_CACHE_%METHOD% (
    set "METHOD_SUPPORTED=!SUPPORT_CACHE_%METHOD%!"
    exit /b
)

set "CHK_DIR=%TEMP%\7zcheck_%RANDOM%_%RANDOM%"
md "%CHK_DIR%" >nul 2>nul
echo probe> "%CHK_DIR%\probe.txt"

"%SEVENZIP_PATH%" a -t7z -mx=1 -m0=%METHOD% "%CHK_DIR%\probe.7z" "%CHK_DIR%\probe.txt" >"%CHK_DIR%\probe.log" 2>&1
set "TEST_RESULT=!errorlevel!"

if !TEST_RESULT! neq 0 (
    set "METHOD_SUPPORTED=0"
) else (
    set "METHOD_SUPPORTED=1"
)

rd /s /q "%CHK_DIR%" >nul 2>nul
set "SUPPORT_CACHE_%METHOD%=!METHOD_SUPPORTED!"
exit /b

:METHOD_SANITY
:: Makes sure COMPRESSION_LEVEL / DICT_SIZE / FAST_BYTES stay valid
call :CHECK_METHOD_SUPPORT
if "%METHOD_SUPPORTED%"=="0" (
    echo.
    echo [Notice] Your installed 7-Zip build does not actually support %METHOD%.
    echo          ^(Brotli/Lizard/flzma2/zstd/lz4/lz5 require a modified build
    echo          such as 7-Zip-ZS: https://github.com/mcmilk/7-Zip-zstd^)
    echo          Falling back to LZMA2.
    set "METHOD=LZMA2"
    pause
)

call :GET_MAX_LEVEL
if %COMPRESSION_LEVEL% gtr %MAX_ALLOWED% (
    echo.
    echo [Notice] Compression level %COMPRESSION_LEVEL% is not valid for %METHOD% ^(max %MAX_ALLOWED%^) - adjusted automatically
    set "COMPRESSION_LEVEL=%MAX_ALLOWED%"
    pause
)

call :IS_DICT_SUPPORTED
if "%DICT_SUPPORTED%"=="0" if /i not "%DICT_SIZE%"=="Auto" (
    echo.
    echo [Notice] Dictionary size ^(-md^) has no effect on %METHOD% - reset to Auto
    set "DICT_SIZE=Auto"
    pause
)

call :IS_FB_SUPPORTED
if "%FB_SUPPORTED%"=="0" if /i not "%FAST_BYTES%"=="Auto" (
    echo.
    echo [Notice] Fast bytes ^(-mfb^) has no effect on %METHOD% - reset to Auto
    set "FAST_BYTES=Auto"
    pause
)
exit /b

:BUILD_ARGS
set "SEVENZIP_ARGS=-t7z -mx=%COMPRESSION_LEVEL% -m0=%METHOD%"
if /i not "%DICT_SIZE%"=="Auto" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -md=%DICT_SIZE%"
if /i not "%FAST_BYTES%"=="Auto" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -mfb=%FAST_BYTES%"
set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -ms=%SOLID_MODE% -mmt=%MULTITHREAD% -bsp1 -bb1"
if not "%ARCHIVE_PASSWORD%"=="" (
    set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -p"%ARCHIVE_PASSWORD%""
    if "%HEADER_ENC%"=="1" set "SEVENZIP_ARGS=%SEVENZIP_ARGS% -mhe=on"
)
exit /b

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
exit /b

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
exit /b

:TEST
if "%DRY_RUN%"=="1" (
    echo. & echo [DRY RUN] Skipping verification/removal step entirely
    exit /b
)

if "%DELETE_AFTER_VERIFY%"=="0" (
    echo. & echo Delete-source-on-success is OFF. Skipping verification/removal step.
    exit /b
)

echo. & echo !SUCCESS_COUNT! archive(s) were created successfully out of !TOTAL_COUNT! folder(s) found
call :CHOICE "Verify all archives and PERMANENTLY delete their source folders on success?"
if errorlevel 2 exit /b

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
exit /b

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
exit /b

:CHOICE
choice /C YN /N /M "%~1 [Y/n]: "
exit /b

:INVALID
echo. & echo [ERROR] Invalid selection. Please choose a valid option between %~1
pause & exit /b
