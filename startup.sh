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
        
        # For standalone builds, we need to use the server.js from .next/standalone
        if [ -f ".next/standalone/server.js" ]; then
            echo "Found standalone server.js"
            
            # Copy necessary files to standalone directory
            echo "Copying public files..."
            if [ -d "public" ]; then
                cp -r public .next/standalone/
            fi
            
            echo "Copying static files..."
            if [ -d ".next/static" ]; then
                cp -r .next/static .next/standalone/.next/
            fi
            
            # Navigate to standalone directory and start
            cd .next/standalone
            echo "Starting standalone server on port ${PORT:-3000}..."
            node server.js
        else
            echo "ERROR: .next/standalone/server.js not found!"
            echo "Contents of .next:"
            ls -la .next/
            exit 1
        fi
    else
        echo "ERROR: .next directory not found!"
        exit 1
    fi
else
    echo "ERROR: No package.json found!"
    exit 1
fi
