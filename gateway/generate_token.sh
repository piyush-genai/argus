#!/bin/bash

# Generate Cognito access token for Argus Gateway
# Extracts token generation functionality from create_gateway.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env file
if [ -f "${SCRIPT_DIR}/.env" ]; then
    echo "📋 Loading environment variables from gateway/.env file..."
    # Source the .env file safely
    set -a  # automatically export all variables
    source "${SCRIPT_DIR}/.env"
    set +a  # stop automatically exporting
else
    echo "❌ Error: No .env file found in gateway directory"
    echo "Please create .env file with COGNITO_* variables"
    exit 1
fi

# Generate Cognito access token
echo "🔑 Generating Cognito access token..."
echo "Make sure your .env file is configured with COGNITO_* variables"

cd "${SCRIPT_DIR}"
if python generate_token.py; then
    echo "✅ Access token generated successfully!"
    echo "📁 Access token saved to .access_token"
else
    echo "❌ Failed to generate access token"
    exit 1
fi