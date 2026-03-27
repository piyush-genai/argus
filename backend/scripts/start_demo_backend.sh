#!/bin/bash
# Start all demo backend servers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$BACKEND_DIR/.." && pwd)"

# Default SSL certificate paths (can be overridden)
SSL_KEYFILE="${SSL_KEYFILE:-}"
SSL_CERTFILE="${SSL_CERTFILE:-}"
HOST="${HOST:-localhost}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ssl-keyfile)
            SSL_KEYFILE="$2"
            shift 2
            ;;
        --ssl-certfile)
            SSL_CERTFILE="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--host HOSTNAME] [--ssl-keyfile PATH] [--ssl-certfile PATH]"
            echo "  --host HOSTNAME       Hostname to bind to (default: localhost)"
            echo "  --ssl-keyfile PATH    Path to SSL private key file"
            echo "  --ssl-certfile PATH   Path to SSL certificate file"
            echo ""
            echo "Environment variables:"
            echo "  HOST                  Hostname to bind to"
            echo "  SSL_KEYFILE           SSL private key file path"
            echo "  SSL_CERTFILE          SSL certificate file path"
            echo ""
            echo "IMPORTANT: If using SSL, ensure your certificate is valid for the specified hostname."
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Starting Argus Demo Backend..."

# Check if we're in the right directory
if [ ! -d "$BACKEND_DIR/data" ]; then
    echo "❌ Backend data directory not found. Please run from backend/ directory"
    exit 1
fi

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Prepare server arguments
SERVER_ARGS="--host '$HOST'"
if [ -n "$SSL_KEYFILE" ] && [ -n "$SSL_CERTFILE" ]; then
    SERVER_ARGS="$SERVER_ARGS --ssl-keyfile '$SSL_KEYFILE' --ssl-certfile '$SSL_CERTFILE'"
    echo "🔒 Using SSL certificates:"
    echo "   Host: $HOST"
    echo "   Key: $SSL_KEYFILE"
    echo "   Cert: $SSL_CERTFILE"
    echo "⚠️  IMPORTANT: Ensure your SSL certificate is valid for hostname '$HOST'"
else
    echo "🌐 Running without SSL (HTTP mode)"
    echo "   Host: $HOST"
fi

# Start FastAPI servers using the proper server implementations
echo "📊 Starting FastAPI servers..."

# Change to servers directory
cd "$BACKEND_DIR/servers"

# K8s API Server (Port 8011)
echo "🏗️  Starting Kubernetes API server on port 8011..."
nohup bash -c "python3 k8s_server.py $SERVER_ARGS" > "$PROJECT_ROOT/logs/k8s_server.log" 2>&1 &

# Logs API Server (Port 8012)
echo "📋 Starting Logs API server on port 8012..."
nohup bash -c "python3 logs_server.py $SERVER_ARGS" > "$PROJECT_ROOT/logs/logs_server.log" 2>&1 &

# Metrics API Server (Port 8013)
echo "📈 Starting Metrics API server on port 8013..."
nohup bash -c "python3 metrics_server.py $SERVER_ARGS" > "$PROJECT_ROOT/logs/metrics_server.log" 2>&1 &

# Runbooks API Server (Port 8014)
echo "📚 Starting Runbooks API server on port 8014..."
nohup bash -c "python3 runbooks_server.py $SERVER_ARGS" > "$PROJECT_ROOT/logs/runbooks_server.log" 2>&1 &

# Wait a moment for servers to start
sleep 2

# Determine protocol for display
if [ -n "$SSL_KEYFILE" ] && [ -n "$SSL_CERTFILE" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

echo "✅ Demo backend started successfully!"
echo "📊 K8s API: $PROTOCOL://$HOST:8011"
echo "📋 Logs API: $PROTOCOL://$HOST:8012" 
echo "📈 Metrics API: $PROTOCOL://$HOST:8013"
echo "📚 Runbooks API: $PROTOCOL://$HOST:8014"
echo ""
echo "📝 Logs are being written to $PROJECT_ROOT/logs/"
echo "🛑 Use './scripts/stop_demo_backend.sh' to stop all servers"