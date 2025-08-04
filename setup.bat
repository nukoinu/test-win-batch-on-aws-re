@echo off
rem AWS CodeBuild セットアップスクリプト実行用バッチファイル
rem 文字コード問題を回避するためのラッパー

echo AWS CodeBuild セットアップを開始します...
echo.

if "%~1"=="" (
    echo 使用方法: %~nx0 アカウントID [リージョン] [リポジトリ名]
    echo 例: %~nx0 123456789012 ap-northeast-1 countdown-test
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
echo セットアップが完了しました。
pause
