# 🚀 Argus SRE Agent - Startup & Testing Guide

## 📋 Overview

This guide covers three ways to run the Argus SRE Agent:

1. **🖥️ Local Testing (CLI)** - Run agent locally on EC2, calls backend APIs directly
2. **☁️ Runtime Testing** - Run agent in AWS AgentCore Runtime (containerized, production-ready)
3. **⚙️ Backend Development** - Test individual backend APIs

---

## 🔧 System Architecture

**All components deployed in `ap-south-1` (Mumbai) region:**

- **Gateway**: Converts REST APIs to MCP tools for agent use
- **Cognito**: JWT authentication (tokens expire every 1 hour)
- **Backend APIs**: 4 FastAPI servers serving fake SRE data (K8s, logs, metrics, runbooks)
- **AgentCore Runtime**: Production containerized agent environment
- **Memory**: Auto-created on first use for conversation context
- **ECR**: Container registry for Runtime deployments

---

## ⚠️ CRITICAL: HTTPS Requirement

**AWS AgentCore Gateway ONLY supports HTTPS endpoints!**

Before starting the agent, you MUST:
1. ✅ Set up SSL certificates at `/opt/ssl/privkey.pem` and `/opt/ssl/fullchain.pem`
2. ✅ Configure backends to use HTTPS with valid certificates
3. ✅ Ensure DDNS domain (`piyushsre.ddns.net`) points to current EC2 public IP

**Without HTTPS, the gateway will fail with SSL/TLS errors!**

---

## Quick Reference
**Use this guide every time you start the agent after EC2 restart or for testing**

---

## Prerequisites
- ✅ AWS Account access with proper IAM permissions
- ✅ EC2 instance created (`ip-172-31-11-16`)
- ✅ SSH key file: `~/.ssh/sre-agent-keypair.pem` (or your key name)
- ✅ No-IP DDNS account (piyushsre.ddns.net)
- ✅ SSL certificates installed at `/opt/ssl/privkey.pem` and `/opt/ssl/fullchain.pem`
- ✅ Cognito user pool configured in `ap-south-1`
- ✅ AgentCore Gateway created in `ap-south-1`
- ✅ Credential provider: `sre-agent-api-key-credential-provider`

---

## 🚀 Part 1: EC2 Instance Startup (Common for All Testing)

### Step 1.1: Start EC2 Instance
**Location:** AWS Console → EC2 → Instances (ap-south-1 region)

1. Navigate to AWS Console
2. Go to EC2 service (ensure region is **ap-south-1**)
3. Select instance: `ip-172-31-11-16`
4. Click **Actions** → **Instance State** → **Start Instance**
5. Wait for status to show **Running** (30-60 seconds)
6. **⚠️ IMPORTANT:** Note the new Public IPv4 address

```bash
# Alternative: Start from AWS CLI
aws ec2 start-instances --instance-ids i-xxxxxxxxx --region ap-south-1
```

---

### Step 1.2: Connect via SSH
**Terminal:** Windows Subsystem for Linux (WSL) or your local terminal

```bash
# Replace <new-public-ip> with the IP from Step 1.1
ssh -i ~/.ssh/sre-agent-keypair.pem ubuntu@<new-public-ip>
```

**Common issues:**
- **"Permission denied"** → Fix with: `chmod 400 ~/.ssh/sre-agent-keypair.pem`
- **"Connection refused"** → Wait 1-2 minutes for EC2 to fully boot
- **"Connection timeout"** → Check Security Group allows SSH (port 22) from your IP

---

### Step 1.3: Update DDNS (No-IP)
**Why needed:** EC2 public IP changes on every stop/start

**Via No-IP Website:**
1. Go to https://www.noip.com/login
2. Login with your credentials
3. Navigate to **Dynamic DNS** → **Hostnames**
4. Find: `piyushsre.ddns.net`
5. Click **Modify** → Update IP to new public IP from Step 1.1
6. Click **Update Hostname**

**Verify DDNS update:**
```bash
nslookup piyushsre.ddns.net
# Should return the new public IP
```

**⏱️ DNS propagation:** May take 1-5 minutes

---

### Step 1.4: Activate Virtual Environment
**Location:** EC2 instance via SSH

```bash
cd ~/argus
source .venv/bin/activate
```

**Verify:**
```bash
pwd
# Should output: /home/ubuntu/argus

which python
# Should output: /home/ubuntu/argus/.venv/bin/python
```

---

### Step 1.5: Refresh Cognito Token (Required Every Hour)
**Why needed:** JWT tokens expire after 1 hour

```bash
cd ~/argus
bash gateway/generate_token.sh
```

**Output should look like:**
```
Token generated and saved to gateway/.access_token
Token expires in 3600 seconds
```

**⚠️ Remember:** Regenerate this token every hour during long sessions!

---

## 🧪 Part 2: Testing Methods

Choose one of the three testing methods below:

---

## Method A: 🖥️ Local Testing (CLI on EC2)

**Use when:** Testing changes quickly, debugging locally, developing features

**Prerequisites:** 
- EC2 instance running and connected (Part 1 complete)
- Backend servers must be running

### Step A.1: Start Backend Servers

```bash
cd ~/argus
export CREDENTIAL_PROVIDER_NAME="sre-agent-api-key-credential-provider"

# Get EC2 private IP automatically
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Start all 4 backend servers with SSL
./scripts/start_demo_backend.sh \
  --host $PRIVATE_IP \
  --ssl-keyfile /opt/ssl/privkey.pem \
  --ssl-certfile /opt/ssl/fullchain.pem
```

**Expected output:**
```
🚀 Starting Argus Demo Backend...
🔒 Using SSL certificates:
Host: 172.31.11.16
Key: /opt/ssl/privkey.pem
Cert: /opt/ssl/fullchain.pem

✅ Demo backend started successfully!
📊 K8s API: https://172.31.11.16:8011
📋 Logs API: https://172.31.11.16:8012
📈 Metrics API: https://172.31.11.16:8013
📚 Runbooks API: https://172.31.11.16:8014
```

**Verify backends are running:**
```bash
# Check processes
ps aux | grep "python.*server.py" | grep -v grep

# Should see 4 processes running
# Test one endpoint (requires valid SSL cert)
curl -k https://piyushsre.ddns.net:8011/
# Should return: {"detail":"Invalid or missing API key"} - this is normal!
```

### Step A.2: Run Agent Locally

```bash
cd ~/argus
uv run argus --provider anthropic --prompt "List the pods in production namespace"
```

**Available CLI options:**
```bash
# Single query
uv run argus --provider anthropic --prompt "Your query here"

# Interactive mode (multi-turn conversation)
uv run argus --provider anthropic --interactive

# Use Bedrock instead of Anthropic
uv run argus --provider bedrock --prompt "Your query"

# Debug mode
DEBUG=true uv run argus --provider anthropic --prompt "Your query"

# Custom user/session IDs
USER_ID=alice SESSION_ID=incident-123 uv run argus --provider anthropic --interactive
```

**Expected output:**
```
2026-08-13 18:34:15 - Initializing Argus SRE Agent...
2026-08-13 18:34:16 - Gateway access token loaded
2026-08-13 18:34:17 - Loaded 21 MCP tools from gateway
2026-08-13 18:34:18 - Agent initialized successfully!

# Investigation Results
**Query:** List the pods in production namespace
...
```

**Stop backends when done:**
```bash
./scripts/stop_demo_backend.sh
```

---

## Method B: ☁️ Runtime Testing (AWS AgentCore)

**Use when:** Testing production deployment, validating container works, end-to-end testing

**Prerequisites:**
- EC2 instance running (Part 1 complete)
- Runtime must be deployed first (see deployment section below)

### Step B.1: Deploy to Runtime (First Time or After Code Changes)

```bash
cd ~/argus

# Create/update deployment environment variables
cat > deployment/.env << EOF
GATEWAY_ACCESS_TOKEN=$(cat gateway/.access_token)
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY sre_agent/.env | cut -d'=' -f2)
CREDENTIAL_PROVIDER_NAME=sre-agent-api-key-credential-provider
EOF

# Build Docker image and deploy to AgentCore Runtime
# This takes 10-20 minutes (ARM64 emulation + ECR push)
export AWS_REGION=ap-south-1
export LLM_PROVIDER=anthropic
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY sre_agent/.env | cut -d'=' -f2)

bash deployment/build_and_deploy.sh argus_sre_agent
```

**What this does:**
1. Builds ARM64 Docker container with agent code
2. Pushes to ECR in `ap-south-1`
3. Creates/updates AgentCore Runtime with container
4. Saves runtime ARN to `deployment/.agent_arn`

**Wait for runtime to become ACTIVE (3-5 minutes):**

Check status in AWS Console:
- Navigate to: **Bedrock** → **AgentCore** → **Runtime** (ensure region is `ap-south-1`)
- Find: `argus_sre_agent`
- Status should show: **Ready** (green checkmark)

### Step B.2: Invoke Runtime

```bash
cd ~/argus

# Test with a query
uv run python deployment/invoke_agent_runtime.py \
  --prompt "List the pods in production namespace" \
  --region ap-south-1
```

**Expected output:**
```
2026-08-13 18:39:00 - Using runtime ARN from .agent_arn: arn:aws:bedrock-agentcore:ap-south-1:...
2026-08-13 18:39:00 - Session ID: invoke-20260813183859-8e3bba9733a8
2026-08-13 18:39:00 - Invoking agent runtime...

{
  "output": {
    "message": "# Investigation Results\n\n**Query:** List the pods..."
  }
}

Message:
# Investigation Results
...
```

**Runtime vs Local differences:**
- ✅ **Runtime**: Production-ready, containerized, observability enabled
- ✅ **Local**: Faster iteration, easier debugging, no build time

---

## Method C: ⚙️ Backend API Development

**Use when:** Developing/testing individual backend APIs, verifying data responses

### Step C.1: Start Single Backend Server

```bash
cd ~/argus/backend/servers

# Start just K8s API
python k8s_server.py \
  --host 0.0.0.0 \
  --ssl-keyfile /opt/ssl/privkey.pem \
  --ssl-certfile /opt/ssl/fullchain.pem

# Or logs API
python logs_server.py --host 0.0.0.0 --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem

# Or metrics API  
python metrics_server.py --host 0.0.0.0 --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem

# Or runbooks API
python runbooks_server.py --host 0.0.0.0 --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem
```

### Step C.2: Test API Endpoints

```bash
# Get API key from credential provider (backend handles this automatically)
cd ~/argus/backend/servers
python retrieve_api_key.py \
  --credential-provider-name sre-agent-api-key-credential-provider \
  --region ap-south-1

# Returns: API Key: your-api-key-here

# Test endpoint with API key
curl -k -H "X-API-Key: your-api-key-here" \
  https://piyushsre.ddns.net:8011/pods?namespace=production

# Without API key (should fail)
curl -k https://piyushsre.ddns.net:8011/pods?namespace=production
# Returns: {"detail":"Invalid or missing API key"}
```

### Step C.3: View API Documentation

```bash
# Open in browser (if you have port forwarding set up)
# K8s API: https://localhost:8011/docs
# Logs API: https://localhost:8012/docs
# Metrics API: https://localhost:8013/docs
# Runbooks API: https://localhost:8014/docs

# Or use curl to see available endpoints
curl -k https://piyushsre.ddns.net:8011/openapi.json | jq '.paths | keys'
```

---

## 🔄 Daily Workflow Examples

### Scenario 1: Quick Local Testing After Code Changes

```bash
# 1. Start EC2 if stopped (AWS Console)

# 2. SSH in
ssh -i ~/.ssh/sre-agent-keypair.pem ubuntu@<new-ip>

# 3. Update DDNS (No-IP website)

# 4. Quick startup
cd ~/argus && source .venv/bin/activate
bash gateway/generate_token.sh
export CREDENTIAL_PROVIDER_NAME="sre-agent-api-key-credential-provider"
./scripts/start_demo_backend.sh --host $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
  --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem

# 5. Test locally
uv run argus --provider anthropic --prompt "Check system health"

# 6. Stop backends when done
./scripts/stop_demo_backend.sh
```

### Scenario 2: Deploy and Test in Runtime

```bash
# 1-3. Same as Scenario 1 (start EC2, SSH, update DDNS)

# 4. Refresh token and deploy
cd ~/argus && source .venv/bin/activate
bash gateway/generate_token.sh

# Create deployment .env
cat > deployment/.env << EOF
GATEWAY_ACCESS_TOKEN=$(cat gateway/.access_token)
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY sre_agent/.env | cut -d'=' -f2)
CREDENTIAL_PROVIDER_NAME=sre-agent-api-key-credential-provider
EOF

# Deploy (10-20 min)
export AWS_REGION=ap-south-1 LLM_PROVIDER=anthropic
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY sre_agent/.env | cut -d'=' -f2)
bash deployment/build_and_deploy.sh argus_sre_agent

# 5. Wait for runtime to become ACTIVE (check AWS Console)

# 6. Test runtime
uv run python deployment/invoke_agent_runtime.py \
  --prompt "List the pods in production namespace"
```

### Scenario 3: Iterative Backend Development

```bash
# 1-3. Same as Scenario 1

# 4. Start just the backend you're working on
cd ~/argus/backend/servers
python k8s_server.py --host 0.0.0.0 \
  --ssl-keyfile /opt/ssl/privkey.pem \
  --ssl-certfile /opt/ssl/fullchain.pem

# 5. Test directly with curl in another terminal
curl -k -H "X-API-Key: $(python retrieve_api_key.py --credential-provider-name sre-agent-api-key-credential-provider --region ap-south-1 | grep 'API Key:' | cut -d' ' -f3)" \
  https://piyushsre.ddns.net:8011/pods?namespace=production

# 6. Make code changes, restart server, test again
```

---

## 🔧 Environment Variables Reference

**Required for all methods:**
- `GATEWAY_ACCESS_TOKEN` - JWT token from Cognito (expires hourly)
- `CREDENTIAL_PROVIDER_NAME` - Must be `sre-agent-api-key-credential-provider`

**Required for Anthropic provider:**
- `ANTHROPIC_API_KEY` - Your Anthropic API key (in `sre_agent/.env`)

**Optional:**
- `AWS_REGION` - AWS region (defaults to `ap-south-1`)
- `DEBUG` - Set to `true` for verbose logging
- `USER_ID` - Custom user identifier (defaults to env or `Piyush`)
- `SESSION_ID` - Custom session identifier (auto-generated if not set)

---

## 🛠️ Troubleshooting Guide

### Issue: Runtime shows "CREATING" status for too long
**Solution:**
- Wait 3-5 minutes after deployment
- Check AWS Console: Bedrock → AgentCore → Runtime (ap-south-1 region)
- If stuck >10 minutes, check deployment logs or redeploy

### Issue: "ValidationException: not in an invocable state"
**Solution:**
- Runtime is still starting, wait for status to become "READY"
- Check in AWS Console or wait a few more minutes

### Issue: "Connection refused" during SSH
**Solution:**
- Wait 1-2 minutes for EC2 to fully boot
- Verify instance state is "Running" in AWS Console
- Check Security Group allows SSH from your IP

### Issue: "Token expired" error
**Solution:**
```bash
cd ~/argus
bash gateway/generate_token.sh
```

### Issue: "Gateway not responding"
**Solution:**
```bash
# Verify DDNS resolution
nslookup piyushsre.ddns.net

# Should return current EC2 public IP
# If not, update DDNS at No-IP website

# Verify gateway in AWS Console
# Bedrock → AgentCore → Gateways (ap-south-1 region)
```

### Issue: Backends not starting or SSL errors
**Solution:**
```bash
# Check if SSL certificates exist
ls -la /opt/ssl/
# Should show: privkey.pem and fullchain.pem

# Check ownership
ls -l /opt/ssl/privkey.pem
# Should be readable by ubuntu user

# Fix permissions if needed
sudo chown ubuntu:ubuntu /opt/ssl/privkey.pem /opt/ssl/fullchain.pem
sudo chmod 600 /opt/ssl/privkey.pem
sudo chmod 644 /opt/ssl/fullchain.pem

# Restart backends
cd ~/argus
export CREDENTIAL_PROVIDER_NAME="sre-agent-api-key-credential-provider"
./scripts/start_demo_backend.sh --host $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
  --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem
```

### Issue: Backends running but agent can't reach them
**Solution:**
```bash
# Check if processes exist
ps aux | grep "python.*server.py" | grep -v grep

# Check if ports are listening
sudo lsof -i :8011
sudo lsof -i :8012
sudo lsof -i :8013
sudo lsof -i :8014

# Check backend logs
tail -30 ~/argus/logs/k8s_server.log

# Restart if needed
./scripts/stop_demo_backend.sh
export CREDENTIAL_PROVIDER_NAME="sre-agent-api-key-credential-provider"
./scripts/start_demo_backend.sh --host $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
  --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem
```

### Issue: "Module not found" or import errors
**Solution:**
```bash
cd ~/argus
source .venv/bin/activate
uv pip install -e .
```

### Issue: Deployment fails with "ConflictException: agent already exists"
**Solution:**
```bash
# Wait 2-3 minutes for AWS cleanup, then retry
sleep 180
export AWS_REGION=ap-south-1 LLM_PROVIDER=anthropic
export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY sre_agent/.env | cut -d'=' -f2)
bash deployment/build_and_deploy.sh argus_sre_agent

# Or use a different runtime name
bash deployment/build_and_deploy.sh argus_sre_agent_v2
```

### Issue: ECR push fails or wrong region
**Solution:**
```bash
# Ensure AWS_REGION is set before deploying
export AWS_REGION=ap-south-1
echo $AWS_REGION  # Verify it's ap-south-1

# Check AWS CLI default region
aws configure get region
# Should return: ap-south-1

# Set permanently in ~/.bashrc
echo 'export AWS_REGION=ap-south-1' >> ~/.bashrc
echo 'export AWS_DEFAULT_REGION=ap-south-1' >> ~/.bashrc
source ~/.bashrc
```

---

## 💾 Before Stopping EC2 Instance

When you're done for the day:

1. **Stop backend servers:**
```bash
cd ~/argus
./scripts/stop_demo_backend.sh
```

2. **Note any important session IDs or reports:**
```bash
ls -lt ~/argus/reports/ | head -5
```

3. **Stop EC2 instance** (AWS Console):
   - EC2 → Instances → Select `ip-172-31-11-16`
   - Actions → Instance State → Stop Instance

**⚠️ Remember:** Public IP will change when you start again!

---

## 📊 System Configuration Summary

**Region:** `ap-south-1` (Mumbai) - ALL components

**EC2 Instance:**
- Hostname: `ip-172-31-11-16`
- Private IP: `172.31.11.16` (static)
- Public IP: Changes on every restart
- Instance Type: t3 or similar
- OS: Ubuntu

**DDNS:**
- Provider: No-IP
- Domain: `piyushsre.ddns.net`
- Update: Manual after each EC2 restart

**SSL Certificates:**
- Location: `/opt/ssl/privkey.pem` and `/opt/ssl/fullchain.pem`
- Valid for: `piyushsre.ddns.net`

**AgentCore Components (ap-south-1):**
- Gateway ID: `myagentcoregatewayargus-sre-agent-gateway-afxx7va5es`
- Gateway URL: https://myagentcoregatewayargus-sre-agent-gateway-afxx7va5es.gateway.bedrock-agentcore.ap-south-1.amazonaws.com
- MCP Tools: 21 tools from 4 backend APIs
- Cognito Pool: `ap-south-1_U4rBAgOMH`
- Credential Provider: `sre-agent-api-key-credential-provider`
- Runtime Name: `argus_sre_agent`
- ECR Repo: `argus_sre_agent` (ap-south-1)

**LLM Provider:**
- Primary: Anthropic Claude (API key in `sre_agent/.env`)
- Alternative: Amazon Bedrock
- Model: Claude Haiku 4.5 or configurable

**Backend APIs (Ports 8011-8014):**
- K8s API: Port 8011
- Logs API: Port 8012
- Metrics API: Port 8013
- Runbooks API: Port 8014
- All require HTTPS with SSL certificates

**Authentication:**
- Type: JWT (Cognito)
- Expiry: 1 hour
- Refresh: `gateway/generate_token.sh`
- Token stored: `gateway/.access_token`

---

## ✅ Pre-flight Checklist

Before running any test:

- [ ] EC2 instance is running (AWS Console, ap-south-1 region)
- [ ] DDNS updated to current public IP (`nslookup piyushsre.ddns.net`)
- [ ] SSH connection established
- [ ] Virtual environment activated (`cd ~/argus && source .venv/bin/activate`)
- [ ] Cognito token refreshed (< 1 hour old) - `bash gateway/generate_token.sh`
- [ ] SSL certificates exist at `/opt/ssl/` with correct permissions

**For Local Testing (Method A):**
- [ ] Backend servers running (`ps aux | grep "python.*server.py"`)
- [ ] All 4 ports listening (8011-8014)

**For Runtime Testing (Method B):**
- [ ] Runtime deployed and status is "READY" (AWS Console)
- [ ] `.agent_arn` file exists in `deployment/` directory

**Ready to test! 🚀**

---

## 🔗 Quick Links

- **AWS Console (ap-south-1):** https://ap-south-1.console.aws.amazon.com/
- **EC2 Instances:** https://ap-south-1.console.aws.amazon.com/ec2/home?region=ap-south-1#Instances:
- **AgentCore Runtimes:** https://ap-south-1.console.aws.amazon.com/bedrock/home?region=ap-south-1#/agentcore/runtimes
- **AgentCore Gateways:** https://ap-south-1.console.aws.amazon.com/bedrock/home?region=ap-south-1#/agentcore/gateways
- **Cognito User Pools:** https://ap-south-1.console.aws.amazon.com/cognito/v2/idp/user-pools?region=ap-south-1
- **ECR Repositories:** https://ap-south-1.console.aws.amazon.com/ecr/repositories?region=ap-south-1
- **No-IP Dashboard:** https://www.noip.com/members/dns/

---

## 💡 Pro Tips

1. **Add bash aliases to `~/.bashrc`:**
```bash
alias sre='cd ~/argus && source .venv/bin/activate'
alias token='cd ~/argus && bash gateway/generate_token.sh'
alias backends-start='cd ~/argus && export CREDENTIAL_PROVIDER_NAME="sre-agent-api-key-credential-provider" && ./scripts/start_demo_backend.sh --host $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem'
alias backends-stop='cd ~/argus && ./scripts/stop_demo_backend.sh'
alias agent-local='uv run argus --provider anthropic'
alias agent-runtime='uv run python deployment/invoke_agent_runtime.py --region ap-south-1'

# Reload
source ~/.bashrc
```

2. **Set AWS region permanently:**
```bash
echo 'export AWS_REGION=ap-south-1' >> ~/.bashrc
echo 'export AWS_DEFAULT_REGION=ap-south-1' >> ~/.bashrc
source ~/.bashrc
```

3. **Create a health check script (`~/check_health.sh`):**
```bash
#!/bin/bash
echo "🔍 Argus System Health Check"
echo "============================"
echo ""
echo "Backend Servers:"
curl -sk https://piyushsre.ddns.net:8011/ > /dev/null && echo "  ✅ K8s API (8011)" || echo "  ❌ K8s API (8011)"
curl -sk https://piyushsre.ddns.net:8012/ > /dev/null && echo "  ✅ Logs API (8012)" || echo "  ❌ Logs API (8012)"
curl -sk https://piyushsre.ddns.net:8013/ > /dev/null && echo "  ✅ Metrics API (8013)" || echo "  ❌ Metrics API (8013)"
curl -sk https://piyushsre.ddns.net:8014/ > /dev/null && echo "  ✅ Runbooks API (8014)" || echo "  ❌ Runbooks API (8014)"
echo ""
echo "DDNS:"
RESOLVED_IP=$(nslookup piyushsre.ddns.net | grep -A1 "Name:" | tail -1 | awk '{print $2}')
CURRENT_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
if [ "$RESOLVED_IP" = "$CURRENT_IP" ]; then
  echo "  ✅ DDNS points to current IP ($CURRENT_IP)"
else
  echo "  ⚠️  DDNS mismatch! Resolved: $RESOLVED_IP, Current: $CURRENT_IP"
fi
echo ""
echo "Token:"
if [ -f ~/argus/gateway/.access_token ]; then
  echo "  ✅ Token file exists"
else
  echo "  ❌ Token file missing - run: bash gateway/generate_token.sh"
fi
echo ""
echo "SSL Certificates:"
if [ -f /opt/ssl/privkey.pem ] && [ -f /opt/ssl/fullchain.pem ]; then
  echo "  ✅ SSL certificates present"
else
  echo "  ❌ SSL certificates missing at /opt/ssl/"
fi
```

Make it executable: `chmod +x ~/check_health.sh`

Run anytime: `~/check_health.sh`

4. **Monitor backend logs in real-time:**
```bash
# Watch all backend logs
tail -f ~/argus/logs/*.log

# Watch just errors
grep -i error ~/argus/logs/*.log | tail -50
```

---

**Need help? Check the troubleshooting section or contact the team.**
