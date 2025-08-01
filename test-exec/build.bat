@echo off
echo Building countdown.exe for Windows...

REM Check if g++ is available
where g++ >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: g++ compiler not found. Please install MinGW-w64 or Visual Studio Build Tools.
    echo.
    echo Recommended option: w64devkit ^(portable, easy setup^)
    echo   1. Download from: https://github.com/skeeto/w64devkit/releases
    echo   2. Extract the archive to any folder ^(e.g., C:\w64devkit^)
    echo   3. Run w64devkit.exe to open terminal with compiler ready
    echo   4. Navigate to this folder and run: build.bat
    echo.
    echo Alternative: MSYS2 ^(more comprehensive^)
    echo   1. Download from: https://www.msys2.org/
    echo   2. Install and run: pacman -S mingw-w64-ucrt-x86_64-gcc
    echo   3. Add to PATH: C:\msys64\ucrt64\bin
    echo.
    echo For Visual Studio: https://visualstudio.microsoft.com/visual-cpp-build-tools/
    pause
    exit /b 1
)

REM Compile the program
echo Compiling countdown.cpp...
g++ -std=c++11 -O2 -Wall -o countdown.exe countdown.cpp

REM Check if compilation was successful
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful! countdown.exe created.
    echo.
    echo Usage examples:
    echo   countdown.exe 10    ^(10 second countdown with 1-second intervals^)
    echo   countdown.exe 300   ^(300 second countdown with 30-second intervals^)
    echo.
) else (
    echo.
    echo Build failed! Please check the error messages above.
    pause
    exit /b 1
)

pause
