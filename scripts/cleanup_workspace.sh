#!/bin/bash

# Workspace Cleanup Script for Argus
# Removes temporary/generated files but keeps source code and configuration

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧹 Argus Workspace Cleanup"
echo "=========================="
echo ""
echo "This will remove temporary and generated files."
echo "Source code and configuration will be preserved."
echo ""

cd "$PROJECT_ROOT"

# Track what we're doing
DELETED_COUNT=0

# Function to safely remove file/directory
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        rm -rf "$path"
        echo "✅ Removed: $description"
        ((DELETED_COUNT++))
    fi
}

echo "📝 Cleaning logs and reports..."
safe_remove "logs/*.log" "Backend server logs"
safe_remove "reports/" "Investigation reports directory"

echo ""
echo "🗑️  Cleaning temporary state files..."
safe_remove ".conversation_state.json" "Conversation state"
safe_remove ".langgraph_conversation_state.json" "LangGraph state"
safe_remove ".multi_agent_conversation_state.json" "Multi-agent state"
safe_remove ".memory_id" "Memory ID file"

echo ""
echo "🔒 Cleaning authentication tokens..."
safe_remove "gateway/.access_token" "Gateway access token"
safe_remove "gateway/.gateway_uri" "Gateway URI file"
safe_remove "gateway/.credentials_provider" "Credentials provider file"

echo ""
echo "📦 Cleaning deployment artifacts..."
safe_remove "deployment/.sre_agent_uri" "Agent container URI"
safe_remove "deployment/.agent_arn" "Agent runtime ARN"
safe_remove "deployment/.env" "Deployment environment"

echo ""
echo "🐍 Cleaning Python cache..."
# Count Python cache before removal
PYCACHE_COUNT=$(find . -type d -name "__pycache__" 2>/dev/null | wc -l)
if [ "$PYCACHE_COUNT" -gt 0 ]; then
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    find . -type f -name "*.pyo" -delete 2>/dev/null || true
    echo "✅ Removed: Python cache directories ($PYCACHE_COUNT __pycache__ folders)"
    ((DELETED_COUNT++))
fi

echo ""
echo "💻 Cleaning OS-specific files..."
# Remove .DS_Store (Mac)
DS_STORE_COUNT=$(find . -name ".DS_Store" 2>/dev/null | wc -l)
if [ "$DS_STORE_COUNT" -gt 0 ]; then
    find . -name ".DS_Store" -delete 2>/dev/null || true
    echo "✅ Removed: .DS_Store files ($DS_STORE_COUNT files)"
    ((DELETED_COUNT++))
fi

# Remove Thumbs.db (Windows)
THUMBS_COUNT=$(find . -name "Thumbs.db" 2>/dev/null | wc -l)
if [ "$THUMBS_COUNT" -gt 0 ]; then
    find . -name "Thumbs.db" -delete 2>/dev/null || true
    echo "✅ Removed: Thumbs.db files ($THUMBS_COUNT files)"
    ((DELETED_COUNT++))
fi

echo ""
echo "=========================================="
echo "✅ Workspace cleanup complete!"
echo ""
if [ "$DELETED_COUNT" -gt 0 ]; then
    echo "📊 Cleaned $DELETED_COUNT categories of files"
else
    echo "📊 Workspace was already clean!"
fi
echo ""
echo "✅ Preserved:"
echo "   • Source code (sre_agent/, backend/, etc.)"
echo "   • Configuration files (.env, config.yaml)"
echo "   • SSL certificates"
echo "   • Virtual environment (.venv/)"
echo "   • Git repository (.git/)"
echo ""
echo "⚠️  Note: OpenAPI spec YAML files are NOT deleted by this script."
echo "   They are generated files but needed for gateway to work."
echo "   To regenerate them: bash backend/openapi_specs/generate_specs.sh"
echo ""
