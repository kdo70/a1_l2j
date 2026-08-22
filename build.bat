@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

echo.
echo ======================================================================
echo   Build Tool
echo ======================================================================
echo.
echo   Build time: %DATE% %TIME%
echo   Project:    %CD%
echo.

set "START_TIME=%TIME: =0%"
set "START_S=0"
for /f "tokens=1-4 delims=:.," %%a in ("%START_TIME%") do (
    set /a "START_S=%%a*360000+%%b*6000+%%c*100+%%d"
)

echo ^> Checking environment...
where java >nul 2>&1
if errorlevel 1 (
    echo   X Java not found!
    goto error
)
echo   + Java is installed

where ant >nul 2>&1
if errorlevel 1 (
    echo   X Ant not found!
    goto error
)
echo   + Apache Ant is installed
echo.

set "MODE=full"
if exist "build" set "MODE=incremental"

if "%MODE%"=="incremental" goto incremental_mode

:full_mode
echo * Full build mode - build folder not found
echo   Compiling gameserver and datapack
echo.
echo ----------------------------------------------------------------------
echo.

echo ^> Step 1: Compiling aCis_gameserver...
echo   Source: source\aCis_gameserver
pushd source\aCis_gameserver
call ant >nul 2>&1
set "ANT_RESULT=%errorlevel%"
popd
if %ANT_RESULT% neq 0 (
    echo   X Compilation failed!
    goto error
)
echo   + Gameserver compiled
echo.

echo ^> Step 2: Compiling aCis_datapack...
echo   Source: source\aCis_datapack
pushd source\aCis_datapack
call ant >nul 2>&1
set "ANT_RESULT=%errorlevel%"
popd
if %ANT_RESULT% neq 0 (
    echo   X Compilation failed!
    goto error
)
echo   + Datapack compiled
echo.

echo ^> Step 3: Assembling build folder...
if exist build rmdir /s /q build >nul 2>&1
mkdir build >nul 2>&1

REM 1. datapack/build -> build (data, sql, tools ? ?.?.)
xcopy /E /I /Y "source\aCis_datapack\build\*" "build\" >nul

REM 2. gameserver/build/dist -> build (login/, gameserver/ ?? ????????? ? ?????????)
xcopy /E /I /Y "source\aCis_gameserver\build\dist\*" "build\" >nul

REM 3. gameserver/build/l2jserver.jar -> login/libs ? gameserver/libs
mkdir build\login\libs >nul 2>&1
mkdir build\gameserver\libs >nul 2>&1
copy /Y "source\aCis_gameserver\build\l2jserver.jar" "build\login\libs\" >nul
copy /Y "source\aCis_gameserver\build\l2jserver.jar" "build\gameserver\libs\" >nul

set "FILE_COUNT=0"
for /r "build" %%f in (*) do set /a "FILE_COUNT+=1" >nul 2>&1
echo   + Build folder assembled (%FILE_COUNT% files)
goto finish

:incremental_mode
echo * Incremental build mode - build folder found
echo   Compiling gameserver only, datapack skipped
echo.
echo ----------------------------------------------------------------------
echo.

echo ^> Step 1: Compiling aCis_gameserver...
echo   Source: source\aCis_gameserver
pushd source\aCis_gameserver
call ant >nul 2>&1
set "ANT_RESULT=%errorlevel%"
popd
if %ANT_RESULT% neq 0 (
    echo   X Compilation failed!
    goto error
)
echo   + Gameserver compiled
echo.

echo ^> Step 2: Updating jar files in build folder...
copy /Y "source\aCis_gameserver\build\l2jserver.jar" "build\login\libs\" >nul
copy /Y "source\aCis_gameserver\build\l2jserver.jar" "build\gameserver\libs\" >nul
echo   + JAR files updated (login + gameserver)
goto finish

:finish
set "END_TIME=%TIME: =0%"
set "END_S=0"
for /f "tokens=1-4 delims=:.," %%a in ("%END_TIME%") do (
    set /a "END_S=%%a*360000+%%b*6000+%%c*100+%%d"
)

set /a "ELAPSED_S=END_S-START_S"
if %ELAPSED_S% lss 0 set /a "ELAPSED_S+=8640000"
set /a "ELAPSED_SEC=ELAPSED_S/100"
set /a "ELAPSED_MS=ELAPSED_S%%100"

echo.
echo ----------------------------------------------------------------------
echo.
echo ======================================================================
echo   + BUILD SUCCESSFUL
echo ======================================================================
echo   Mode:   %MODE%
echo   Time:   %ELAPSED_SEC%.%ELAPSED_MS%s
echo   Output: %CD%\build
echo ======================================================================
echo.
pause
exit /b 0

:error
echo.
echo ======================================================================
echo   X BUILD FAILED
echo ======================================================================
echo.
pause
exit /b 1