@echo off
rem AWS CodeBuild �Z�b�g�A�b�v�X�N���v�g���s�p�o�b�`�t�@�C��
rem �����R�[�h����������邽�߂̃��b�p�[

echo AWS CodeBuild �Z�b�g�A�b�v���J�n���܂�...
echo.

if "%~1"=="" (
    echo �g�p���@: %~nx0 �A�J�E���gID [���[�W����] [���|�W�g����]
    echo ��: %~nx0 123456789012 ap-northeast-1 countdown-test
    pause
    exit /b 1
)

set ACCOUNT_ID=%~1
set REGION=%~2
set REPO_NAME=%~3

if "%REGION%"=="" set REGION=ap-northeast-1
if "%REPO_NAME%"=="" set REPO_NAME=countdown-test

echo AccountId: %ACCOUNT_ID%
echo Region: %REGION%
echo Repository: %REPO_NAME%
echo.

powershell -ExecutionPolicy Bypass -Command "chcp 65001; & '%~dp0setup-codebuild.ps1' -AccountId '%ACCOUNT_ID%' -Region '%REGION%' -RepositoryName '%REPO_NAME%'"

echo.
echo �Z�b�g�A�b�v���������܂����B
pause
