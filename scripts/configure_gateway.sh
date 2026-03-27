#!/bin/bash

# Configure Gateway Script for Argus
# Manages gateway configuration and backend services

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# File paths
GATEWAY_URI_FILE="$PROJECT_ROOT/gateway/.gateway_uri"
ACCESS_TOKEN_FILE="$PROJECT_ROOT/gateway/.access_token"
AGENT_CONFIG_FILE="$PROJECT_ROOT/sre_agent/config/agent_config.yaml"
ENV_FILE="$PROJECT_ROOT/sre_agent/.env"

# Default gateway URI for reverse operation
DEFAULT_GATEWAY_URI="https://your-agentcore-gateway-endpoint.gateway.bedrock-agentcore.us-east-1.amazonaws.com"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cleanup       Reset gateway URI to default placeholder"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Description:"
    echo "  This script configures the Argus to use a real AgentCore gateway."
    echo "  It reads the gateway URI and access token from the gateway directory"
    echo "  and updates the configuration files accordingly."
    echo ""
    echo "  Normal operation:"
    echo "  1. Stops running backend servers"
    echo "  2. Generates new access token"
    echo "  3. Gets EC2 instance private IP"
    echo "  4. Starts backend servers with SSL"
    echo "  5. Updates gateway URI in agent config"
    echo "  6. Updates access token in .env file"
    echo ""
    echo "  Cleanup operation (--cleanup):"
    echo "  - Resets gateway URI to placeholder value"
    echo "  - Useful for development/testing mode"
}

# Function to check if file exists
check_file() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        echo "❌ Error: $description not found at $file"
        return 1
    fi
    return 0
}

# Function to update YAML file
update_gateway_uri_in_yaml() {
    local uri="$1"
    local config_file="$2"
    
    echo "📝 Updating gateway URI in $config_file"
    
    # Use sed to update the gateway URI line
    if grep -q "^  uri:" "$config_file"; then
        # Update existing uri line
        sed -i "s|^  uri:.*|  uri: \"$uri\"|" "$config_file"
    else
        # Add uri line if gateway section exists
        if grep -q "^gateway:" "$config_file"; then
            sed -i "/^gateway:/a\\  uri: \"$uri\"" "$config_file"
        else
            # Add entire gateway section
            echo "" >> "$config_file"
            echo "# Gateway configuration" >> "$config_file"
            echo "gateway:" >> "$config_file"
            echo "  uri: \"$uri\"" >> "$config_file"
        fi
    fi
    
    echo "✅ Gateway URI updated to: $uri"
}

# Function to update or create .env file
update_env_file() {
    local token="$1"
    local env_file="$2"
    
    echo "📝 Updating access token in $env_file"
    
    # Create .env file if it doesn't exist
    if [ ! -f "$env_file" ]; then
        echo "# Argus Environment Variables" > "$env_file"
    fi
    
    # Update or add GATEWAY_ACCESS_TOKEN
    if grep -q "^GATEWAY_ACCESS_TOKEN=" "$env_file"; then
        # Update existing token
        sed -i "s|^GATEWAY_ACCESS_TOKEN=.*|GATEWAY_ACCESS_TOKEN=\"$token\"|" "$env_file"
    else
        # Add new token
        echo "GATEWAY_ACCESS_TOKEN=\"$token\"" >> "$env_file"
    fi
    
    echo "✅ Access token updated in .env file"
}

# Function to get EC2 instance private IP
get_private_ip() {
    echo "🌐 Getting EC2 instance private IP..."
    
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
      -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    if [ -z "$PRIVATE_IP" ]; then
        echo "❌ Failed to get private IP address"
        exit 1
    fi
    
    echo "📍 Private IP: $PRIVATE_IP"
}

# Function to stop backend servers
stop_backend() {
    echo "🛑 Stopping backend servers..."
    if [ -f "$PROJECT_ROOT/backend/scripts/stop_demo_backend.sh" ]; then
        cd "$PROJECT_ROOT"
        bash backend/scripts/stop_demo_backend.sh
    else
        echo "⚠️  Backend stop script not found, continuing..."
    fi
}

# Function to start backend servers
start_backend() {
    echo "🚀 Starting backend servers..."
    
    # Check if SSL certificates exist
    SSL_KEY="/etc/letsencrypt/live/$(hostname -f)/privkey.pem"
    SSL_CERT="/etc/letsencrypt/live/$(hostname -f)/fullchain.pem"
    
    # Alternative SSL paths to check
    if [ ! -f "$SSL_KEY" ] || [ ! -f "$SSL_CERT" ]; then
        SSL_KEY="/opt/ssl/privkey.pem"
        SSL_CERT="/opt/ssl/fullchain.pem"
    fi
    
    if [ -f "$SSL_KEY" ] && [ -f "$SSL_CERT" ]; then
        echo "🔒 Found SSL certificates, starting with HTTPS"
        cd "$PROJECT_ROOT"
        echo "🔧 Executing: bash backend/scripts/start_demo_backend.sh --host \"$PRIVATE_IP\" --ssl-keyfile \"$SSL_KEY\" --ssl-certfile \"$SSL_CERT\""
        bash backend/scripts/start_demo_backend.sh --host "$PRIVATE_IP" --ssl-keyfile "$SSL_KEY" --ssl-certfile "$SSL_CERT"
    else
        echo "⚠️  SSL certificates not found, starting with HTTP"
        cd "$PROJECT_ROOT"
        echo "🔧 Executing: bash backend/scripts/start_demo_backend.sh --host \"$PRIVATE_IP\""
        bash backend/scripts/start_demo_backend.sh --host "$PRIVATE_IP"
    fi
}

# Function to generate new token
generate_token() {
    echo "🔑 Generating new access token..."
    if [ -f "$PROJECT_ROOT/gateway/generate_token.sh" ]; then
        cd "$PROJECT_ROOT/gateway"
        bash generate_token.sh
    else
        echo "❌ Error: Token generation script not found"
        exit 1
    fi
}

# Parse command line arguments
CLEANUP_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP_MODE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔧 Argus Gateway Configuration Script"
echo "=========================================="

if [ "$CLEANUP_MODE" = true ]; then
    echo "🔄 Running in cleanup mode - resetting to default configuration"
    
    # Check if agent config file exists
    if ! check_file "$AGENT_CONFIG_FILE" "Agent config file"; then
        exit 1
    fi
    
    # Update gateway URI to default
    update_gateway_uri_in_yaml "$DEFAULT_GATEWAY_URI" "$AGENT_CONFIG_FILE"
    
    # Remove or comment out access token from .env file
    if [ -f "$ENV_FILE" ]; then
        echo "🧹 Removing access token from .env file"
        if grep -q "^GATEWAY_ACCESS_TOKEN=" "$ENV_FILE"; then
            # Comment out the existing token line
            sed -i 's|^GATEWAY_ACCESS_TOKEN=.*|# GATEWAY_ACCESS_TOKEN=removed_in_reverse_mode|' "$ENV_FILE"
            echo "✅ Access token removed from .env file"
        else
            echo "ℹ️  No access token found in .env file"
        fi
    else
        echo "ℹ️  No .env file found"
    fi
    
    echo "✅ Configuration reset to default (development mode)"
    echo "🔧 Gateway URI set to: $DEFAULT_GATEWAY_URI"
    echo "🔑 Access token removed from .env file"
    
else
    echo "⚙️  Running in normal mode - configuring for production gateway"
    
    # Step 1: Stop running servers
    stop_backend
    
    # Step 2: Generate new token
    generate_token
    
    # Step 3: Get private IP
    get_private_ip
    
    # Step 4: Start backend servers
    start_backend
    
    # Step 5: Check required files
    echo "📂 Checking required files..."
    
    if ! check_file "$GATEWAY_URI_FILE" "Gateway URI file"; then
        echo "💡 Please ensure gateway/.gateway_uri contains your AgentCore gateway endpoint"
        exit 1
    fi
    
    if ! check_file "$ACCESS_TOKEN_FILE" "Access token file"; then
        echo "💡 Please run gateway/generate_token.sh first to create access token"
        exit 1
    fi
    
    if ! check_file "$AGENT_CONFIG_FILE" "Agent config file"; then
        exit 1
    fi
    
    # Step 6: Read gateway URI and access token
    echo "📖 Reading configuration files..."
    
    GATEWAY_URI=$(cat "$GATEWAY_URI_FILE" | tr -d '\n\r' | xargs)
    ACCESS_TOKEN=$(cat "$ACCESS_TOKEN_FILE" | tr -d '\n\r' | xargs)
    
    if [ -z "$GATEWAY_URI" ]; then
        echo "❌ Error: Gateway URI is empty"
        exit 1
    fi
    
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "❌ Error: Access token is empty"
        exit 1
    fi
    
    echo "📋 Gateway URI: $GATEWAY_URI"
    echo "🔑 Access token: ${ACCESS_TOKEN:0:20}..." # Show first 20 chars only
    
    # Step 7: Update configuration files
    update_gateway_uri_in_yaml "$GATEWAY_URI" "$AGENT_CONFIG_FILE"
    update_env_file "$ACCESS_TOKEN" "$ENV_FILE"
    
    echo ""
    echo "✅ Configuration completed successfully!"
    echo "🎯 Gateway URI: $GATEWAY_URI"
    echo "📁 Updated files:"
    echo "   - $AGENT_CONFIG_FILE"
    echo "   - $ENV_FILE"
    echo ""
    echo "🚀 Backend servers are running with SSL on $PRIVATE_IP"
    echo "🔧 Argus is now configured for production gateway"
fi

echo ""
echo "🏁 Script completed!"