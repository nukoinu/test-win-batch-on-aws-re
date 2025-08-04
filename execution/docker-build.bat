@echo off
echo Building countdown.exe using Docker...

REM Check if Docker is available
docker --version >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Docker is not installed or not running.
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

echo.
echo Building Docker image with cross-compilation tools...
docker build -t countdown-builder .

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Docker build failed! Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Extracting countdown.exe from Docker container...

REM Create a temporary container to extract the executable
docker create --name temp-countdown countdown-builder
docker cp temp-countdown:/app/countdown.exe .
docker rm temp-countdown

if exist countdown.exe (
    echo.
    echo Build successful! countdown.exe extracted from Docker container.
    echo.
    echo The executable was built using cross-compilation and should work on Windows.
    echo.
    echo Usage examples:
    echo   countdown.exe 10    ^(10 second countdown with 1-second intervals^)
    echo   countdown.exe 300   ^(300 second countdown with 30-second intervals^)
    echo.
    echo Testing the executable...
    echo.
    countdown.exe 5
) else (
    echo.
    echo Failed to extract countdown.exe from Docker container.
    exit /b 1
)

echo.
echo Docker build and extraction completed successfully!
pause
