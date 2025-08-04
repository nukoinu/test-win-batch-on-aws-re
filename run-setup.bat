@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -Command "& '%~dp0setup-codebuild.ps1' %*"
pause
