# 🔒 Quick SSL Setup Commands

**⚠️ Run these commands to set up SSL certificates for AWS AgentCore Gateway**

## Prerequisites
- EC2 instance running
- DDNS updated to EC2 public IP (piyushsre.ddns.net)
- Ports 80, 443, 8011-8014 open in Security Group

---

## 1. Install Certbot
```bash
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

---

## 2. Update DDNS First!
```bash
# Check your EC2 public IP
curl http://checkip.amazonaws.com

# Go to https://www.noip.com/login
# Update piyushsre.ddns.net to point to the IP above

# Verify DNS propagation (wait 1-5 min)
nslookup piyushsre.ddns.net
```

---

## 3. Get SSL Certificate
```bash
# Stop any service on port 80
sudo lsof -i :80
# If needed: sudo systemctl stop apache2

# Request certificate
sudo certbot certonly --standalone -d piyushsre.ddns.net

# Copy to /opt/ssl/
sudo mkdir -p /opt/ssl
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/privkey.pem /opt/ssl/
sudo cp /etc/letsencrypt/live/piyushsre.ddns.net/fullchain.pem /opt/ssl/
sudo chmod 644 /opt/ssl/*.pem

# Verify
ls -la /opt/ssl/
```

---

## 4. Update OpenAPI Specs
```bash
cd ~/argus-sre-agent/backend/openapi_specs

# Update to HTTPS
sed -i 's|url: http://.*:8011|url: https://piyushsre.ddns.net:8011|g' k8s_api.yaml
sed -i 's|url: http://.*:8012|url: https://piyushsre.ddns.net:8012|g' logs_api.yaml
sed -i 's|url: http://.*:8013|url: https://piyushsre.ddns.net:8013|g' metrics_api.yaml
sed -i 's|url: http://.*:8014|url: https://piyushsre.ddns.net:8014|g' runbooks_api.yaml

# Verify
grep "url:" *.yaml

cd ../..
```

---

## 5. Upload Specs to S3
```bash
cd backend/openapi_specs
aws s3 cp k8s_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp logs_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp metrics_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
aws s3 cp runbooks_api.yaml s3://argus-sre-agent-specs-piyush-2026/devops-multiagent-demo/
cd ../..
```

---

## 6. Start Backends with SSL
```bash
cd ~/argus-sre-agent
source .venv/bin/activate
bash scripts/configure_gateway.sh
```

**Look for:** `🔒 Found SSL certificates, starting with HTTPS`

---

## 7. Verify HTTPS Works
```bash
curl https://piyushsre.ddns.net:8011/health
curl https://piyushsre.ddns.net:8012/health
curl https://piyushsre.ddns.net:8013/health
curl https://piyushsre.ddns.net:8014/health

# Check logs
tail -30 logs/k8s_server.log
```

---

## 8. Launch Agent
```bash
argus --provider anthropic
```

**Test query:** "Check payment-service pod status"

---

## Done! ✅

Your Argus SRE Agent is now configured with HTTPS and ready for AWS AgentCore Gateway.

**See full guide:** [SSL_SETUP_GUIDE.md](SSL_SETUP_GUIDE.md)
