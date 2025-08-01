#include <iostream>
#include <string>
#include <chrono>
#include <thread>

void showUsage() {
    std::cout << "Usage: countdown.exe [seconds]" << std::endl;
    std::cout << "  seconds: positive integer specifying countdown duration" << std::endl;
}

void showError(const std::string& message) {
    std::cout << "Error: " << message << std::endl;
}

bool isValidNumber(const std::string& str, int& result) {
    try {
        size_t pos;
        result = std::stoi(str, &pos);
        // Check if entire string was consumed and result is non-negative
        return pos == str.length() && result >= 0;
    } catch (const std::exception&) {
        return false;
    }
}

void countdown(int seconds) {
    int interval;
    int step;
    
    if (seconds < 100) {
        // 1-99 seconds: 1 second interval
        interval = 1000; // milliseconds
        step = 1;
    } else {
        // 100+ seconds: 1/10 of total time interval
        interval = (seconds * 1000) / 10; // milliseconds
        step = seconds / 10;
    }
    
    int current = seconds;
    
    while (current >= 0) {
        std::cout << current << std::endl;
        std::cout.flush(); // Ensure immediate output for Docker/batch environments
        
        if (current == 0) {
            break;
        }
        
        // Sleep for the specified interval
        std::this_thread::sleep_for(std::chrono::milliseconds(interval));
        
        current -= step;
        // Ensure we don't go below 0
        if (current < 0) {
            current = 0;
        }
    }
}

int main(int argc, char* argv[]) {
    // Check argument count
    if (argc != 2) {
        showUsage();
        return 1;
    }
    
    int seconds;
    std::string input(argv[1]);
    
    // Validate input
    if (!isValidNumber(input, seconds)) {
        showError("Invalid input. Please provide a non-negative integer.");
        showUsage();
        return 1;
    }
    
    if (seconds < 0) {
        showError("Negative numbers are not allowed.");
        showUsage();
        return 1;
    }
    
    // Start countdown
    countdown(seconds);
    
    return 0;
}
