@echo off
setlocal enabledelayedexpansion

REM ECR Push Script for Windows Image
REM Pushes Windows countdown test image to Amazon ECR

echo ==========================================
echo ECR Push Script - Windows Image
echo ==========================================

REM Configuration - MODIFY THESE VALUES
set AWS_REGION=us-east-1
set AWS_ACCOUNT_ID=123456789012
set ECR_REPOSITORY=countdown-test-windows
set LOCAL_IMAGE_NAME=countdown-test-windows
set LOCAL_IMAGE_TAG=latest

REM Parse command line arguments
if "%1"=="" (
    echo Usage: %0 ^<aws-account-id^> [region] [repository-name]
    echo.
    echo Example: %0 123456789012 us-east-1 countdown-test-windows
    echo.
    echo Current configuration:
    echo   Account ID: %AWS_ACCOUNT_ID%
    echo   Region: %AWS_REGION%
    echo   Repository: %ECR_REPOSITORY%
    echo.
    set /p CONTINUE="Continue with current configuration? (y/N): "
    if /i not "!CONTINUE!"=="y" exit /b 1
) else (
    set AWS_ACCOUNT_ID=%1
    if not "%2"=="" set AWS_REGION=%2
    if not "%3"=="" set ECR_REPOSITORY=%3
)

set ECR_URI=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com
set FULL_IMAGE_NAME=%ECR_URI%/%ECR_REPOSITORY%:%LOCAL_IMAGE_TAG%

echo Configuration:
echo   AWS Account ID: %AWS_ACCOUNT_ID%
echo   AWS Region: %AWS_REGION%
echo   ECR Repository: %ECR_REPOSITORY%
echo   Local Image: %LOCAL_IMAGE_NAME%:%LOCAL_IMAGE_TAG%
echo   Target ECR URI: %FULL_IMAGE_NAME%
echo.

REM Check if AWS CLI is available
aws --version >nul 2>&1
if errorlevel 1 (
    echo Error: AWS CLI is not installed or not in PATH
    echo Please install AWS CLI v2 and configure credentials
    exit /b 1
)

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not in PATH
    exit /b 1
)

REM Check if local image exists
docker image inspect %LOCAL_IMAGE_NAME%:%LOCAL_IMAGE_TAG% >nul 2>&1
if errorlevel 1 (
    echo Error: Local image %LOCAL_IMAGE_NAME%:%LOCAL_IMAGE_TAG% not found
    echo Please build the image first using build-image.bat
    exit /b 1
)

echo Step 1: Creating ECR repository if it doesn't exist...
aws ecr describe-repositories --repository-names %ECR_REPOSITORY% --region %AWS_REGION% >nul 2>&1
if errorlevel 1 (
    echo Creating ECR repository: %ECR_REPOSITORY%
    aws ecr create-repository --repository-name %ECR_REPOSITORY% --region %AWS_REGION%
    if errorlevel 1 (
        echo Error: Failed to create ECR repository
        exit /b 1
    )
) else (
    echo Repository %ECR_REPOSITORY% already exists
)

echo.
echo Step 2: Getting ECR login token...
for /f "tokens=*" %%i in ('aws ecr get-login-password --region %AWS_REGION%') do set ECR_TOKEN=%%i
if "%ECR_TOKEN%"=="" (
    echo Error: Failed to get ECR login token
    exit /b 1
)

echo Step 3: Logging into ECR...
echo %ECR_TOKEN% | docker login --username AWS --password-stdin %ECR_URI%
if errorlevel 1 (
    echo Error: Docker login to ECR failed
    exit /b 1
)

echo.
echo Step 4: Tagging image for ECR...
docker tag %LOCAL_IMAGE_NAME%:%LOCAL_IMAGE_TAG% %FULL_IMAGE_NAME%
if errorlevel 1 (
    echo Error: Failed to tag image
    exit /b 1
)

echo.
echo Step 5: Pushing image to ECR...
echo This may take several minutes for Windows images...
docker push %FULL_IMAGE_NAME%
if errorlevel 1 (
    echo Error: Failed to push image to ECR
    exit /b 1
)

echo.
echo ==========================================
echo Push completed successfully!
echo ==========================================
echo ECR Image URI: %FULL_IMAGE_NAME%
echo.
echo You can now use this image in:
echo   - AWS Batch job definitions
echo   - ECS task definitions
echo   - Other AWS services
echo.
echo To pull the image:
echo   docker pull %FULL_IMAGE_NAME%
echo ==========================================

endlocal
