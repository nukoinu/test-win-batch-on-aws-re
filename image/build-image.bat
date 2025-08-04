@echo off
setlocal enabledelayedexpansion

REM Windows Docker Image Build Script
REM Builds Windows Server 2022 based countdown test image

echo ==========================================
echo Windows Countdown Test Image Builder
echo ==========================================

REM Configuration
set IMAGE_NAME=countdown-test-windows
set IMAGE_TAG=latest
set DOCKERFILE=Dockerfile

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not in PATH
    echo Please install Docker Desktop and ensure it's running
    exit /b 1
)

REM Check if Docker daemon is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker daemon is not running
    echo Please start Docker Desktop
    exit /b 1
)

REM Switch to Windows containers if needed (Docker Desktop)
echo Switching to Windows containers...
docker version --format "{{.Server.Os}}" | findstr "windows" >nul
if errorlevel 1 (
    echo Switching Docker to Windows container mode...
    powershell -Command "& 'C:\Program Files\Docker\Docker\DockerCli.exe' -SwitchWindowsEngine"
    timeout /t 10 /nobreak >nul
)

REM Check if countdown.exe exists in execution directory
if not exist "..\execution\countdown.exe" (
    echo countdown.exe not found in execution directory, building from source...
    pushd ..\execution
    call build.bat
    if errorlevel 1 (
        echo Error: Failed to build countdown.exe
        popd
        exit /b 1
    )
    popd
)

REM Copy required files to current directory for Docker build context
echo Copying files for Docker build context...
copy "..\execution\countdown.exe" . >nul
copy "..\execution\countdown.cpp" . >nul

echo Building Docker image...
echo Image: %IMAGE_NAME%:%IMAGE_TAG%
echo Dockerfile: %DOCKERFILE%
echo.

REM Build the Docker image
docker build -f %DOCKERFILE% -t %IMAGE_NAME%:%IMAGE_TAG% .
if errorlevel 1 (
    echo Error: Docker build failed
    goto cleanup
)

REM Clean up copied files
:cleanup
if exist "countdown.exe" del "countdown.exe" >nul 2>&1
if exist "countdown.cpp" del "countdown.cpp" >nul 2>&1

if errorlevel 1 (
    exit /b 1
)

echo.
echo ==========================================
echo Build completed successfully!
echo ==========================================
echo Image: %IMAGE_NAME%:%IMAGE_TAG%
echo.
echo To test the image:
echo   docker run --rm %IMAGE_NAME%:%IMAGE_TAG% powershell -File C:\app\run.ps1 10
echo.
echo To run interactively:
echo   docker run -it --rm %IMAGE_NAME%:%IMAGE_TAG% powershell
echo.
echo To push to ECR:
echo   push-to-ecr.bat ^<aws-account-id^> [region] [repository-name]
echo ==========================================

endlocal
