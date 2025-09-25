#!/bin/bash

echo "=== Azure App Service Startup Script ==="
echo "Current directory: $(pwd)"
echo "Contents of /home/site/wwwroot:"
ls -la /home/site/wwwroot/

# Navigate to the app directory
cd /home/site/wwwroot

# Check what files we have
if [ -f "package.json" ]; then
    echo "Found package.json"

    # Check if .next directory exists
    if [ -d ".next" ]; then
        echo "Found .next directory"
        echo "Starting application with npm start..."
        npm start
    else
        echo "ERROR: .next directory not found!"
        echo "This deployment requires a pre-built .next directory"
        exit 1
    fi
else
    echo "ERROR: No package.json found!"
    echo "Available files:"
    ls -la
    exit 1
fi