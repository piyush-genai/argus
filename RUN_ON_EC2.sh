#!/bin/bash
# Argus SRE Agent - SSL Setup and Deployment Script
# Run this script on your EC2 instance after SSH connection

set -e

echo "=========================================="
echo "🔒 Argus SRE Agent SSL Setup & Deployment"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo "ℹ️  $1"
}

# Variables
DDNS_DOMAIN="piyushsre.ddns.net"
PROJECT_DIR="$HOME/argus-sre-agent"
S3_BUCKET="argus-sre-agent-specs-piyush-2026"
S3_PREFIX="devops-multiagent-demo"

echo "📋 Configuration:"
echo "   DDNS Domain: $DDNS_DOMAIN"
echo "   Project Directory: $PROJECT_DIR"
echo "   S3 Bucket: $S3_BUCKET"
echo ""

# Step 1: Check if running on EC2
echo "🔍 Step 1: Checking if running on EC2..."
if curl -s -m 2 http://169.254.169.254/latest/meta-data/ > /dev/null; then
    EC2_PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
    print_success "Running on EC2. Public IP: $EC2_PUBLIC_IP"
else
    print_warning "Not running on EC2 or metadata service unavailable"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Step 2: Check DDNS
echo "🌐 Step 2: Checking DDNS configuration..."
DDNS_IP=$(dig +short $DDNS_DOMAIN | tail -n1)
if [ -n "$DDNS_IP" ]; then
    print_info "DDNS resolves to: $DDNS_IP"
    if [ "$DDNS_IP" != "$EC2_PUBLIC_IP" ]; then
        print_warning "DDNS IP ($DDNS_IP) doesn't match EC2 public IP ($EC2_PUBLIC_IP)"
        echo "   Please update DDNS at https://www.noip.com/login"
        read -p "Press Enter after updating DDNS..."
    else
        print_success "DDNS is correctly configured"
    fi
else
    print_error "DDNS domain $DDNS_DOMAIN doesn't resolve"
    echo "   Please configure DDNS first"
    exit 1
fi
echo ""

# Step 3: Install certbot if not present
echo "🔧 Step 3: Installing certbot..."
if ! command -v certbot &> /dev/null; then
    print_info "Installing certbot via snap..."
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    print_success "Certbot installed"
else
    print_success "Certbot already installed"
fi
echo ""

# Step 4: Check for existing certificates
echo "🔍 Step 4: Checking for existing SSL certificates..."
if [ -f "/etc/letsencrypt/live/$DDNS_DOMAIN/privkey.pem" ]; then
    print_success "SSL certificates already exist for $DDNS_DOMAIN"
    CERT_EXPIRY=$(sudo openssl x509 -in "/etc/letsencrypt/live/$DDNS_DOMAIN/fullchain.pem" -noout -enddate | cut -d= -f2)
    print_info "Certificate expires: $CERT_EXPIRY"
    
    read -p "Use existing certificates? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SKIP_CERT_GENERATION=true
    else
        SKIP_CERT_GENERATION=false
    fi
else
    print_info "No existing certificates found"
    SKIP_CERT_GENERATION=false
fi
echo ""

# Step 5: Get SSL certificates if needed
if [ "$SKIP_CERT_GENERATION" = false ]; then
    echo "🔒 Step 5: Obtaining SSL certificate from Let's Encrypt..."
    
    # Check if port 80 is in use
    if sudo lsof -i :80 > /dev/null 2>&1; then
        print_warning "Port 80 is in use. Attempting to stop services..."
        sudo systemctl stop apache2 2>/dev/null || true
        sudo systemctl stop nginx 2>/dev/null || true
    fi
    
    print_info "Running certbot for $DDNS_DOMAIN..."
    sudo certbot certonly --standalone -d $DDNS_DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
    
    if [ $? -eq 0 ]; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate"
        echo "   Please check:"
        echo "   1. DDNS is updated and propagated"
        echo "   2. Port 80 is accessible from the internet"
        echo "   3. EC2 Security Group allows inbound port 80"
        exit 1
    fi
else
    print_info "Skipping certificate generation"
fi
echo ""

# Step 6: Copy certificates to /opt/ssl/
echo "📋 Step 6: Copying certificates to /opt/ssl/..."
sudo mkdir -p /opt/ssl
sudo cp "/etc/letsencrypt/live/$DDNS_DOMAIN/privkey.pem" /opt/ssl/
sudo cp "/etc/letsencrypt/live/$DDNS_DOMAIN/fullchain.pem" /opt/ssl/
sudo chmod 644 /opt/ssl/*.pem
print_success "Certificates copied to /opt/ssl/"
ls -la /opt/ssl/
echo ""

# Step 7: Navigate to project directory
echo "📁 Step 7: Navigating to project directory..."
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Project directory not found: $PROJECT_DIR"
    exit 1
fi
cd "$PROJECT_DIR"
print_success "In directory: $(pwd)"
echo ""

# Step 8: Activate virtual environment
echo "🐍 Step 8: Activating virtual environment..."
if [ ! -d ".venv" ]; then
    print_error "Virtual environment not found. Creating one..."
    uv venv --python 3.12
fi
source .venv/bin/activate
print_success "Virtual environment activated"
echo ""

# Step 9: Install package
echo "📦 Step 9: Installing argus package..."
uv pip install -e .
print_success "Package installed"
echo ""

# Step 10: Update OpenAPI specs
echo "📝 Step 10: Updating OpenAPI specs to use HTTPS..."
cd backend/openapi_specs

# Backup existing specs
cp k8s_api.yaml k8s_api.yaml.bak 2>/dev/null || true
cp logs_api.yaml logs_api.yaml.bak 2>/dev/null || true
cp metrics_api.yaml metrics_api.yaml.bak 2>/dev/null || true
cp runbooks_api.yaml runbooks_api.yaml.bak 2>/dev/null || true

# Update all specs to HTTPS with DDNS domain
sed -i "s|url: http://.*:8011|url: https://$DDNS_DOMAIN:8011|g" k8s_api.yaml
sed -i "s|url: http://.*:8012|url: https://$DDNS_DOMAIN:8012|g" logs_api.yaml
sed -i "s|url: http://.*:8013|url: https://$DDNS_DOMAIN:8013|g" metrics_api.yaml
sed -i "s|url: http://.*:8014|url: https://$DDNS_DOMAIN:8014|g" runbooks_api.yaml

print_success "OpenAPI specs updated"
echo "   URLs now point to: https://$DDNS_DOMAIN:801X"

# Verify changes
echo ""
print_info "Verifying spec changes:"
grep "url:" *.yaml | grep -v ".bak"
echo ""

cd ../..

# Step 11: Upload specs to S3
echo "☁️  Step 11: Uploading OpenAPI specs to S3..."
cd backend/openapi_specs

aws s3 cp k8s_api.yaml "s3://$S3_BUCKET/$S3_PREFIX/" && print_success "k8s_api.yaml uploaded"
aws s3 cp logs_api.yaml "s3://$S3_BUCKET/$S3_PREFIX/" && print_success "logs_api.yaml uploaded"
aws s3 cp metrics_api.yaml "s3://$S3_BUCKET/$S3_PREFIX/" && print_success "metrics_api.yaml uploaded"
aws s3 cp runbooks_api.yaml "s3://$S3_BUCKET/$S3_PREFIX/" && print_success "runbooks_api.yaml uploaded"

# Verify S3 upload
echo ""
print_info "Verifying S3 upload:"
aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/"
echo ""

cd ../..

# Step 12: Generate Cognito token
echo "🔑 Step 12: Generating Cognito access token..."
cd gateway
bash generate_token.sh
if [ $? -eq 0 ]; then
    print_success "Access token generated"
else
    print_error "Failed to generate access token"
    exit 1
fi
cd ..
echo ""

# Step 13: Start backend servers with SSL
echo "🚀 Step 13: Starting backend servers with SSL..."
bash scripts/configure_gateway.sh

if [ $? -eq 0 ]; then
    print_success "Backend servers started"
else
    print_error "Failed to start backend servers"
    exit 1
fi
echo ""

# Step 14: Verify backends are running
echo "🔍 Step 14: Verifying backend servers..."
sleep 3

BACKENDS_OK=true
for PORT in 8011 8012 8013 8014; do
    if sudo lsof -i :$PORT > /dev/null 2>&1; then
        print_success "Port $PORT is listening"
    else
        print_error "Port $PORT is not listening"
        BACKENDS_OK=false
    fi
done

if [ "$BACKENDS_OK" = false ]; then
    print_error "Some backend servers failed to start"
    echo "   Check logs in: logs/*.log"
    exit 1
fi
echo ""

# Step 15: Test HTTPS endpoints
echo "🧪 Step 15: Testing HTTPS endpoints..."
for PORT in 8011 8012 8013 8014; do
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$DDNS_DOMAIN:$PORT/health" || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
        print_success "https://$DDNS_DOMAIN:$PORT - HTTP $HTTP_CODE (OK)"
    else
        print_warning "https://$DDNS_DOMAIN:$PORT - HTTP $HTTP_CODE (May need time to start)"
    fi
done
echo ""

# Step 16: Display final status
echo "=========================================="
echo "🎉 Setup Complete!"
echo "=========================================="
echo ""
print_success "SSL certificates installed and configured"
print_success "Backend servers running with HTTPS"
print_success "OpenAPI specs updated and uploaded to S3"
print_success "Cognito token generated"
echo ""
echo "📊 Backend URLs:"
echo "   K8s API:     https://$DDNS_DOMAIN:8011"
echo "   Logs API:    https://$DDNS_DOMAIN:8012"
echo "   Metrics API: https://$DDNS_DOMAIN:8013"
echo "   Runbooks API: https://$DDNS_DOMAIN:8014"
echo ""
echo "📝 Logs location: $PROJECT_DIR/logs/"
echo ""
echo "🚀 Ready to launch agent:"
echo "   argus --provider anthropic"
echo ""
echo "🧪 Test with query:"
echo '   > Check payment-service pod status'
echo ""
print_warning "Remember: Gateway may take 5-10 minutes to refresh specs from S3"
print_warning "Remember: Token expires every hour - refresh with: cd gateway && bash generate_token.sh && cd .."
echo ""
