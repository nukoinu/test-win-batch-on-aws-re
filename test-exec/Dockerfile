# Multi-stage Dockerfile for cross-platform Windows EXE building
# This allows building Windows executables on any platform

# Build stage
FROM debian:bullseye-slim as builder

# Install cross-compilation tools for Windows
RUN apt-get update && apt-get install -y \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source code
COPY countdown.cpp .

# Compile Windows executable using MinGW cross-compiler
RUN x86_64-w64-mingw32-g++ \
    -std=c++11 \
    -O2 \
    -Wall \
    -static-libgcc \
    -static-libstdc++ \
    -static \
    -o countdown.exe \
    countdown.cpp

# Runtime stage (for testing - can run with Wine if needed)
FROM debian:bullseye-slim as runtime

# Install Wine for testing Windows executables (optional)
RUN apt-get update && apt-get install -y \
    wine \
    && rm -rf /var/lib/apt/lists/*

# Copy the built executable
COPY --from=builder /app/countdown.exe /app/countdown.exe

WORKDIR /app

# Default command to show the executable was built successfully
CMD ["ls", "-la", "countdown.exe"]

# To test the executable with Wine (uncomment the following line):
# CMD ["wine", "./countdown.exe", "10"]
