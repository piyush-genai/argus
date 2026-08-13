#!/bin/bash

# Exit on error
set -e

echo "🛑 Stopping Argus Demo Backend..."

# Kill all backend server processes
echo "Stopping backend servers..."
pkill -f "python.*k8s_server.py" 2>/dev/null || true
pkill -f "python.*logs_server.py" 2>/dev/null || true
pkill -f "python.*metrics_server.py" 2>/dev/null || true
pkill -f "python.*runbooks_server.py" 2>/dev/null || true

# Wait a moment for processes to terminate
sleep 2

# Verify they're stopped
RUNNING=$(ps aux | grep "python.*server.py" | grep -v grep | wc -l)

if [ "$RUNNING" -eq 0 ]; then
    echo "✅ All backend servers stopped successfully!"
else
    echo "⚠️  Warning: $RUNNING backend server(s) still running"
    echo "Running processes:"
    ps aux | grep "python.*server.py" | grep -v grep
fi

echo ""
echo "📊 Current status:"
echo "K8s API (8011): $(lsof -i :8011 > /dev/null 2>&1 && echo 'Still running' || echo 'Stopped')"
echo "Logs API (8012): $(lsof -i :8012 > /dev/null 2>&1 && echo 'Still running' || echo 'Stopped')"
echo "Metrics API (8013): $(lsof -i :8013 > /dev/null 2>&1 && echo 'Still running' || echo 'Stopped')"
echo "Runbooks API (8014): $(lsof -i :8014 > /dev/null 2>&1 && echo 'Still running' || echo 'Stopped')"
