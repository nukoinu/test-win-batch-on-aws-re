# Windows Server 2022 based Docker image for countdown test execution
# Multi-stage build for optimized image size

# Stage 1: Build stage (if needed for compilation)
FROM mcr.microsoft.com/windows/server:ltsc2022 as builder

# Set working directory
WORKDIR C:\build

# Copy source code and executable from execution directory
COPY ../execution/countdown.cpp .
COPY ../execution/countdown.exe .

# Stage 2: Runtime stage
FROM mcr.microsoft.com/windows/server:ltsc2022 as runtime

# Set working directory
WORKDIR C:\app

# Copy the executable from builder stage
COPY --from=builder C:\build\countdown.exe .

# Create a simple PowerShell script for easier execution
RUN powershell -Command "Set-Content -Path 'C:\app\run.ps1' -Value 'param([string]$seconds); if ($seconds) { & C:\app\countdown.exe $seconds } else { & C:\app\countdown.exe }'"

# Set default command
CMD ["powershell", "-File", "C:\\app\\run.ps1"]

# Labels for image metadata
LABEL maintainer="Test Team"
LABEL description="Windows Server 2022 based countdown test execution image"
LABEL version="1.0"
LABEL base-image="mcr.microsoft.com/windows/server:ltsc2022"
