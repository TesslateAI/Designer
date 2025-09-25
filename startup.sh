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

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing dependencies with pnpm..."
        npm install -g pnpm
        pnpm install --prod
    fi

    # Check if .next directory exists
    if [ -d ".next" ]; then
        echo "Found .next directory, starting with npm start..."
        npm start
    else
        echo ".next directory not found! Building the application..."
        npm install -g pnpm
        pnpm build
        echo "Build complete, starting application..."
        npm start
    fi
elif [ -f "server.js" ]; then
    echo "Found standalone server.js, running directly..."
    node server.js
else
    echo "ERROR: No package.json or server.js found!"
    echo "Available files:"
    ls -la
    exit 1
fi