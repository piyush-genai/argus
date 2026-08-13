#!/bin/bash

# Commit script for region migration and documentation updates

cd "$(dirname "$0")"

echo "📝 Preparing to commit changes..."
echo ""

# Show what will be committed
echo "📊 Changed files:"
git status --short

echo ""
read -p "Do you want to commit these changes? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "✅ Staging all changes..."
    git add -A
    
    echo "✅ Creating commit..."
    git commit -m "feat: migrate all services to ap-south-1 region + comprehensive guides

- Migrate default region from us-east-1 to ap-south-1 across all components
  - Update sre_agent/constants.py with new region defaults
  - Update memory, deployment, and gateway configs
  - Fix all fallback logic in multi_agent_langgraph.py and agent_nodes.py
  - Update agent_config.yaml with actual ap-south-1 gateway URI

- Add comprehensive documentation
  - STARTUP_CHECKLIST.md: 3 testing methods (local CLI, runtime, backend dev)
  - SYNC_TO_EC2.md: Complete sync guide for local <-> EC2
  - Scripts: stop_demo_backend.sh for clean shutdown

- Benefits:
  - All components in same region (lower latency, no cross-region costs)
  - Consistent defaults (no need to export AWS_REGION every time)
  - Better documentation for onboarding and daily operations"
    
    echo ""
    echo "✅ Commit created successfully!"
    echo ""
    echo "📤 Next steps:"
    echo "  1. Push to remote (if configured): git push origin main"
    echo "  2. Sync to EC2: Follow SYNC_TO_EC2.md guide"
    echo ""
else
    echo "❌ Commit cancelled"
fi
