#!/bin/bash
# Azure App Service startup script for Next.js standalone

# Navigate to the app directory
cd /home/site/wwwroot

# Run the standalone Next.js server
node server.js