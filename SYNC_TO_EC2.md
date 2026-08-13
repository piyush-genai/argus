# 🔄 Sync Local Changes to EC2

## Overview
This guide helps you sync your local workspace with the EC2 instance after making code changes.

---

## ✅ Current Changes (Ready to Commit)

### 1. Region Migration (`ap-south-1`)
All AWS services now default to `ap-south-1` (Mumbai) region:
- Gateway
- Cognito
- Memory
- Runtime
- ECR

**Files changed:**
- `sre_agent/constants.py`
- `sre_agent/memory/config.py`
- `sre_agent/memory/client.py`
- `sre_agent/agent_nodes.py`
- `sre_agent/multi_agent_langgraph.py`
- `sre_agent/config/agent_config.yaml`
- `deployment/build_and_deploy.sh`
- `deployment/deploy_agent_runtime.py`
- `deployment/invoke_agent_runtime.py`
- `gateway/main.py`
- `gateway/create_credentials_provider.py`
- `gateway/observability.py`
- `backend/servers/retrieve_api_key.py`
- `scripts/manage_memories.py`

### 2. New Files
- `STARTUP_CHECKLIST.md` - Complete startup and testing guide
- `scripts/stop_demo_backend.sh` - Script to stop backend servers
- `QUICK_SSL_SETUP.md` - Quick SSL setup guide (if exists)
- `SSL_SETUP_GUIDE.md` - Detailed SSL guide (if exists)
- `RUN_ON_EC2.sh` - EC2 startup helper (if exists)

---

## 📦 Step 1: Commit Your Changes

```bash
cd ~/workspace/projects/argus/argus-sre-agent

# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "feat: migrate all services to ap-south-1 region + add comprehensive startup guide

- Change default region from us-east-1 to ap-south-1 across all components
- Update constants, config files, and deployment scripts
- Add STARTUP_CHECKLIST.md with 3 testing methods (local, runtime, backend)
- Add stop_demo_backend.sh script
- Update gateway URI in agent_config.yaml to actual ap-south-1 gateway
- Fix all region fallback logic to use ap-south-1"

# Push to remote (if you have a git remote configured)
git push origin main
```

**Note:** If you don't have a remote repository, you can skip `git push`.

---

## 🚀 Step 2: Sync to EC2

### Option A: Using Git (Recommended if you have remote repo)

**On EC2:**
```bash
# Start your EC2 instance first
# SSH in

cd ~/argus
git pull origin main

# If there are conflicts, resolve them or force pull:
git fetch origin
git reset --hard origin/main
```

### Option B: Using rsync (Direct sync from local to EC2)

**From your local machine (WSL):**
```bash
# Replace <EC2-IP> with your current public IP
EC2_IP=<your-ec2-public-ip>

rsync -avz --exclude='.git/' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='logs/' \
  --exclude='reports/' \
  --exclude='.env' \
  --exclude='.access_token' \
  --exclude='.gateway_uri' \
  ~/workspace/projects/argus/argus-sre-agent/ \
  ubuntu@$EC2_IP:~/argus/
```

### Option C: Manual file copy (Specific files only)

If you only want to sync specific files:

**From local (WSL):**
```bash
EC2_IP=<your-ec2-public-ip>

# Copy specific files
scp -i ~/.ssh/sre-agent-keypair.pem \
  ~/workspace/projects/argus/argus-sre-agent/STARTUP_CHECKLIST.md \
  ubuntu@$EC2_IP:~/argus/

scp -i ~/.ssh/sre-agent-keypair.pem \
  ~/workspace/projects/argus/argus-sre-agent/scripts/stop_demo_backend.sh \
  ubuntu@$EC2_IP:~/argus/scripts/

# Copy all changed Python files
scp -i ~/.ssh/sre-agent-keypair.pem \
  ~/workspace/projects/argus/argus-sre-agent/sre_agent/*.py \
  ubuntu@$EC2_IP:~/argus/sre_agent/
```

---

## 🧹 Step 3: Clean Up (Both Local and EC2)

### Files Safe to Delete

These are generated/temporary files that can be safely removed:

```bash
# Backend - generated OpenAPI specs (regenerated from templates)
rm -f backend/openapi_specs/k8s_api.yaml
rm -f backend/openapi_specs/logs_api.yaml
rm -f backend/openapi_specs/metrics_api.yaml
rm -f backend/openapi_specs/runbooks_api.yaml

# Logs and reports
rm -rf logs/*.log
rm -rf reports/*.md

# Temporary/state files
rm -f .conversation_state.json
rm -f .langgraph_conversation_state.json
rm -f .multi_agent_conversation_state.json
rm -f .memory_id

# Deployment artifacts (regenerated on deploy)
rm -f deployment/.sre_agent_uri
rm -f deployment/.env
rm -f deployment/.agent_arn

# Gateway artifacts (regenerated on use)
rm -f gateway/.access_token
rm -f gateway/.gateway_uri
rm -f gateway/.credentials_provider

# Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete
find . -type f -name "*.pyo" -delete
```

### Automated Cleanup Script

**Run this on both local and EC2:**

```bash
cd ~/argus  # or ~/workspace/projects/argus/argus-sre-agent on local

bash scripts/cleanup.sh
```

**If `cleanup.sh` doesn't exist, create it:**

```bash
cat > scripts/cleanup.sh << 'EOF'
#!/bin/bash

echo "🧹 Cleaning up Argus workspace..."

# Remove generated files
echo "Removing generated OpenAPI specs..."
rm -f backend/openapi_specs/k8s_api.yaml
rm -f backend/openapi_specs/logs_api.yaml
rm -f backend/openapi_specs/metrics_api.yaml
rm -f backend/openapi_specs/runbooks_api.yaml

# Remove logs and reports
echo "Removing logs and reports..."
rm -rf logs/*.log
rm -rf reports/*.md

# Remove state files
echo "Removing state files..."
rm -f .conversation_state.json
rm -f .langgraph_conversation_state.json
rm -f .multi_agent_conversation_state.json
rm -f .memory_id

# Remove deployment artifacts
echo "Removing deployment artifacts..."
rm -f deployment/.sre_agent_uri
rm -f deployment/.env
rm -f deployment/.agent_arn

# Remove gateway artifacts  
echo "Removing gateway artifacts..."
rm -f gateway/.access_token
rm -f gateway/.gateway_uri
rm -f gateway/.credentials_provider

# Remove Python cache
echo "Removing Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete
find . -type f -name "*.pyo" -delete

# Remove .DS_Store (Mac)
find . -name ".DS_Store" -delete 2>/dev/null

echo "✅ Cleanup complete!"
EOF

chmod +x scripts/cleanup.sh
```

---

## ⚠️ Files to KEEP (Never Delete)

**Critical files:**
- `sre_agent/.env` - Contains ANTHROPIC_API_KEY
- `gateway/.env` - Contains Cognito credentials
- `.cognito_config` - Cognito backup config
- `.venv/` - Virtual environment (reinstall with `uv venv` if deleted)
- `backend/data/` - Mock data for testing
- SSL certificates (`/opt/ssl/privkey.pem`, `/opt/ssl/fullchain.pem`)

---

## 🔍 Step 4: Verify Sync

**On EC2 after syncing:**

```bash
cd ~/argus

# Check git status
git status

# Verify key files exist
ls -la STARTUP_CHECKLIST.md
ls -la scripts/stop_demo_backend.sh
cat sre_agent/constants.py | grep "ap-south-1"

# Should show: default_region: str = Field(default="ap-south-1"...)
```

---

## 📊 Differences Between Local and EC2

### Local Workspace (`~/workspace/projects/argus/argus-sre-agent`)
- **Purpose**: Development, code editing, git commits
- **Has**: Full git history, your IDE settings
- **Doesn't need**: Backend running, SSL certs, runtime deployed

### EC2 Workspace (`~/argus`)
- **Purpose**: Testing, running backends, deploying to runtime
- **Has**: SSL certificates, running backends, access to AWS services
- **Doesn't need**: Full git history (can be shallow clone)

**Key difference:** EC2 has runtime environment (SSL, backends, AWS access), local has development tools.

---

## 🎯 Recommended Workflow

1. **Develop locally**: Edit code in `~/workspace/projects/argus/argus-sre-agent`
2. **Commit changes**: `git commit -m "your changes"`
3. **Push to remote** (if you have one): `git push origin main`
4. **Sync to EC2**: Start EC2, SSH in, `git pull` or `rsync`
5. **Test on EC2**: Run backends, test agent
6. **Deploy to runtime** (if needed): `bash deployment/build_and_deploy.sh argus_runtime`

---

## 🚨 Troubleshooting

### "Permission denied" when syncing
**Solution:**
```bash
# Fix SSH key permissions
chmod 400 ~/.ssh/sre-agent-keypair.pem
```

### "Git conflicts" after pull
**Solution:**
```bash
# On EC2 - reset to remote state
git fetch origin
git reset --hard origin/main
```

### "Files out of sync" between local and EC2
**Solution:**
```bash
# Compare specific file
diff <(ssh ubuntu@<EC2-IP> "cat ~/argus/sre_agent/constants.py") \
     ~/workspace/projects/argus/argus-sre-agent/sre_agent/constants.py

# If different, use rsync to force sync
```

### "Module not found" after sync
**Solution:**
```bash
# On EC2 - reinstall package
cd ~/argus
source .venv/bin/activate
uv pip install -e .
```

---

## ✅ Post-Sync Checklist

After syncing changes to EC2:

- [ ] Code changes synced
- [ ] Cleanup script run (if needed)
- [ ] Virtual environment activated
- [ ] Package reinstalled (`uv pip install -e .`)
- [ ] Region defaults verified (`grep "ap-south-1" sre_agent/constants.py`)
- [ ] New scripts made executable (`chmod +x scripts/*.sh`)
- [ ] STARTUP_CHECKLIST.md accessible

**Ready to test! Follow STARTUP_CHECKLIST.md for next steps.**
