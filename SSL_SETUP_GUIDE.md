# 🔒 SSL Certificate Setup Guide for Argus SRE Agent

## ⚠️ Why SSL is Required

**AWS AgentCore Gateway ONLY works with HTTPS endpoints!**

From the official AWS README:
> **⚠️ IMPORTANT:** Amazon Bedrock AgentCore Gateway **only works with HTTPS endpoints**. For example, you can register your Amazon EC2 with [no-ip.com](https://www.noip.com/) and obtain a certificate from [letsencrypt.org](https://letsencrypt.org/)

Without valid SSL certificates:
- ❌ Gateway connections will fail with SSL/TLS errors
- ❌ MCP tools will be unavailable
- ❌ Agent investigations will not work

---

## Prerequisites

Before setting up SSL certificates, ensure you have:

1. ✅ **EC2 instance running** with public IP
2. ✅ **DDNS hostname registered** (e.g., piyushsre.ddns.net)
3. ✅ **DDNS pointing to your EC2 public IP** (updated after each restart)
4. ✅ **EC2 Security Group allows inbound traffic** on:
   - Port 80 (HTTP) - Required for Let's Encrypt validation
   - Port 443 (HTTPS) - Required for HTTPS connections
   - Ports 8011-8014 - Required for backend API servers

---

## Option 1: Let's Encrypt (Recommended)

Let's Encrypt provides free, automated SSL certificates that are trusted by all browsers and AWS services.

### Step 1: Install Certbot

```bash
# SSH into your EC2 instance
ssh -i ~/.ssh/sre-agent-keypair.pem ubuntu@<your-ec2-public-ip>

# Install certbot via snap (recommended method)
sudo snap install --classic certbot

# Create symlink for easy access
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Verify installation
certbot --version
```

### Step 2: Update DDNS Before Certificate Request

**CRITICAL:** Your DDNS hostname must be pointing to your current EC2 public IP!

```bash
# Get your current public IP
curl http://checkip.amazonaws.com

# Update No-IP DDNS:
# 1. Go to https://www.noip.com/login
# 2. Navigate to Dynamic DNS → Hostnames
# 3. Update piyushsre.ddns.net to point to the IP above

# Verify DNS propagation (wait 1-5 minutes)
nslookup piyushsre.ddns.net
dig piyushsre.ddns.net +short

# Both should return your EC2 public IP
```

### Step 3: Stop Any Services on Port 80

Let's Encrypt uses port 80 for domain validation.

```bash
# Check if anything is using port 80
sudo lsof -i :80

# If Apache/Nginx is running, stop it temporarily
sudo systemctl stop apache2    # If Apache is installed
sudo systemctl stop nginx       # If Nginx is installed

# Or kill specific process
sudo kill <PID>
```

### Step 4: Request SSL Certificate

```bash
# Request certificate using standalone mode
sudo certbot certonly --standalone -d piyushsre.ddns.net

# Follow the prompts:
# - Enter email address for renewal notifications
# - Agree to Terms of Service
# - Choose whether to share email with EFF
```

**Expected output:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem
This certificate expires on 2026-11-06.
```

### Step 5: Copy Certificates to /opt/ssl/

The `configure_gateway.sh` script looks for certificates in `/opt/ssl/` or `/etc/letsencrypt/live/<hostname>/`.

```bash
# Create SSL directory
sudo mkdir -p /opt/ssl

# Copy certificates
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem /opt/ssl/

# Set appropriate permissions
sudo chmod 644 /opt/ssl/*.pem

# Verify files exist
ls -la /opt/ssl/
```

**Output should show:**
```
-rw-r--r-- 1 root root 1765 Aug  8 09:00 privkey.pem
-rw-r--r-- 1 root root 3810 Aug  8 09:00 fullchain.pem
```

### Step 6: Update OpenAPI Specs for HTTPS

```bash
# Navigate to project directory
cd ~/argus-sre-agent

# Activate virtual environment
source .venv/bin/activate

# Update OpenAPI specs to use HTTPS with your DDNS domain
cd backend/openapi_specs

# Update all 4 spec files
sed -i 's|url: http://.*:8011|url: https://piyushsre.ddns.net:8011|g' k8s_api.yaml
sed -i 's|url: http://.*:8012|url: https://piyushsre.ddns.net:8012|g' logs_api.yaml
sed -i 's|url: http://.*:8013|url: https://piyushsre.ddns.net:8013|g' metrics_api.yaml
sed -i 's|url: http://.*:8014|url: https://piyushsre.ddns.net:8014|g' runbooks_api.yaml

# Verify changes
grep "url:" *.yaml

# Expected output:
# k8s_api.yaml:  - url: https://piyushsre.ddns.net:8011
# logs_api.yaml:  - url: https://piyushsre.ddns.net:8012
# metrics_api.yaml:  - url: https://piyushsre.ddns.net:8013
# runbooks_api.yaml:  - url: https://piyushsre.ddns.net:8014

cd ../..
```

### Step 7: Upload Updated Specs to S3

AWS AgentCore Gateway reads OpenAPI specs from S3.

```bash
# Check your S3 bucket name from gateway config
cat gateway/config.yaml | grep s3_bucket

# Upload specs to S3
cd backend/openapi_specs
aws s3 cp k8s_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp logs_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp metrics_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp runbooks_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/

# Verify upload
aws s3 ls s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/

cd ../..
```

### Step 8: Start Backend Servers with SSL

```bash
# The configure_gateway.sh script will automatically detect SSL certificates
bash scripts/configure_gateway.sh
```

**Expected output:**
```
🚀 Starting backend servers...
🔒 Found SSL certificates, starting with HTTPS
   Host: 172.31.11.16
   Key: /opt/ssl/privkey.pem
   Cert: /opt/ssl/fullchain.pem
⚠️  IMPORTANT: Ensure your SSL certificate is valid for hostname '172.31.11.16'
📍 Private IP: 172.31.11.16
✅ Demo backend started successfully!
📊 K8s API: https://172.31.11.16:8011
📋 Logs API: https://172.31.11.16:8012
📈 Metrics API: https://172.31.11.16:8013
📚 Runbooks API: https://172.31.11.16:8014
```

### Step 9: Verify HTTPS is Working

```bash
# Test HTTPS endpoints with your DDNS domain
curl https://piyushsre.ddns.net:8011/health
curl https://piyushsre.ddns.net:8012/health
curl https://piyushsre.ddns.net:8013/health
curl https://piyushsre.ddns.net:8014/health

# Check backend logs for SSL startup
grep "SSL" logs/*_server.log
grep "https" logs/*_server.log

# View full startup log
tail -30 logs/k8s_server.log
```

**Expected responses:**
- HTTP 200 OK with JSON response
- OR HTTP 401 Unauthorized (normal - means server is running, auth required)
- NOT SSL/TLS errors

### Step 10: Set Up Auto-Renewal

Let's Encrypt certificates expire after 90 days. Certbot automatically sets up renewal.

```bash
# Test renewal (dry run - doesn't actually renew)
sudo certbot renew --dry-run

# Check renewal timer status
sudo systemctl status snap.certbot.renew.timer

# View renewal logs
sudo journalctl -u snap.certbot.renew.service
```

**To manually renew certificates:**
```bash
# Renew all certificates that are due for renewal
sudo certbot renew

# After renewal, copy new certificates to /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem /opt/ssl/
sudo chmod 644 /opt/ssl/*.pem

# Restart backend servers to use new certificates
cd ~/argus-sre-agent
source .venv/bin/activate
bash scripts/configure_gateway.sh
```

---

## Option 2: Self-Signed Certificate (Development Only)

**⚠️ WARNING:** Self-signed certificates are NOT trusted by AWS services. Use only for local testing.

```bash
# Generate self-signed certificate
sudo mkdir -p /opt/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/ssl/privkey.pem \
  -out /opt/ssl/fullchain.pem \
  -subj "/CN=piyushsre.ddns.net"

sudo chmod 644 /opt/ssl/*.pem

# Start backends
cd ~/argus-sre-agent
bash scripts/configure_gateway.sh
```

**Limitations:**
- AWS AgentCore Gateway will reject self-signed certificates
- Only useful for local curl testing with `-k` flag
- Not suitable for production

---

## Option 3: Use AWS Certificate Manager (ACM)

If you prefer AWS-managed certificates:

1. Register a domain with Route 53
2. Create certificate in ACM
3. Set up Application Load Balancer (ALB)
4. Configure ALB to terminate SSL and forward to backend servers
5. Update OpenAPI specs with ALB DNS name

**Note:** This approach is more complex and has additional costs (ALB, Route 53).

---

## Troubleshooting

### Issue: "Certbot: Unable to find a standalone server at port 80"

**Cause:** Port 80 is already in use or blocked by firewall.

**Solution:**
```bash
# Check what's using port 80
sudo lsof -i :80

# Stop the service
sudo systemctl stop <service-name>

# Or kill the process
sudo kill <PID>

# Check EC2 Security Group allows inbound port 80
# AWS Console → EC2 → Security Groups → Check Inbound Rules
```

### Issue: "Domain validation failed"

**Cause:** DDNS hostname doesn't point to EC2 public IP.

**Solution:**
```bash
# Verify DDNS is updated
nslookup piyushsre.ddns.net
curl http://checkip.amazonaws.com

# Wait 5-10 minutes for DNS propagation
# Update DDNS at no-ip.com if IPs don't match
```

### Issue: "Certificate expired"

**Cause:** Let's Encrypt certificates expire after 90 days.

**Solution:**
```bash
# Renew certificate
sudo certbot renew

# Copy new certificates
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem /opt/ssl/
sudo chmod 644 /opt/ssl/*.pem

# Restart backends
bash scripts/configure_gateway.sh
```

### Issue: "SSL certificate verify failed" when testing with curl

**Cause:** Certificate is valid for DDNS domain but you're testing with IP address.

**Solution:**
```bash
# Use DDNS domain in curl commands
curl https://piyushsre.ddns.net:8011/health

# OR test with private IP and skip verification (development only)
curl -k https://172.31.11.16:8011/health
```

### Issue: Backend logs show "SSL certificates not found"

**Cause:** Certificates not in expected locations.

**Solution:**
```bash
# Check certificate locations
ls -la /opt/ssl/
ls -la /etc/letsencrypt/live/piyushsre.ddns.net/

# Copy certificates to /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem /opt/ssl/
sudo chmod 644 /opt/ssl/*.pem
```

---

## Certificate Lifecycle Management

### After EC2 Restart

```bash
# 1. Start EC2 instance (public IP changes!)
# 2. Update DDNS with new public IP at no-ip.com
# 3. SSH into EC2
# 4. Certificates in /opt/ssl/ are still valid (stored on EBS volume)
# 5. Start backends - they will use existing certificates
cd ~/argus-sre-agent
source .venv/bin/activate
bash scripts/configure_gateway.sh
```

**Note:** You do NOT need to get new certificates after EC2 restart, as long as:
- Certificates haven't expired (90 days)
- DDNS hostname still resolves to new EC2 IP
- Certificate files still exist in /opt/ssl/

### Monthly Maintenance

```bash
# Check certificate expiration
sudo certbot certificates

# Output shows:
# Certificate Name: piyushsre.ddns.net
#   Domains: piyushsre.ddns.net
#   Expiry Date: 2026-11-06 08:30:00+00:00 (VALID: 89 days)

# If expiring soon (< 30 days), renew manually
sudo certbot renew
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/*.pem /opt/ssl/
```

---

## Quick Reference

### Check SSL Certificate Status
```bash
sudo certbot certificates
openssl x509 -in /opt/ssl/fullchain.pem -noout -text | grep -A2 "Validity"
```

### Verify Backend SSL Configuration
```bash
grep "ssl" logs/k8s_server.log
ps aux | grep "ssl-keyfile"
```

### Test HTTPS Endpoints
```bash
curl -v https://piyushsre.ddns.net:8011/health 2>&1 | grep "SSL"
```

### Force Certificate Renewal
```bash
sudo certbot renew --force-renewal
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/*.pem /opt/ssl/
bash scripts/configure_gateway.sh
```

---

## Next Steps

After SSL setup is complete:

1. ✅ Verify backends are running with HTTPS
2. ✅ Test HTTPS endpoints with curl
3. ✅ Start the Argus SRE Agent: `argus --provider anthropic`
4. ✅ Test agent query: "Check payment-service pod status"

If agent still shows SSL/TLS errors:
- Verify OpenAPI specs in S3 have HTTPS URLs
- Wait 5-10 minutes for gateway to refresh specs
- Check gateway logs in AWS CloudWatch
- Recreate gateway if needed: `cd gateway && ./create_gateway.sh`

---

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot User Guide](https://eff-certbot.readthedocs.io/)
- [AWS AgentCore Gateway Documentation](https://docs.aws.amazon.com/bedrock-agentcore/)
- [No-IP DDNS Setup](https://www.noip.com/support/knowledgebase/getting-started-with-no-ip-com/)

---

**⚠️ REMEMBER:** After every EC2 restart:
1. Update DDNS to new public IP
2. Certificates remain valid (stored on EBS)
3. Just restart backends with `bash scripts/configure_gateway.sh`
