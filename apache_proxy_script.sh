#!/bin/bash

# Apache to Nginx Reverse Proxy Configuration Generator with SSL Support
# Created by: Bhushan Barbuddhe
# Version: 1.0
# Date: $(date +%Y-%m-%d)
# Usage: ./create-apache-proxy.sh domain.com [apache_port] [ssl]
#
# This script automatically creates Nginx reverse proxy configurations
# for Apache websites with optional SSL certificate generation.
#
# Features:
# - Automatic SSL certificate generation (Let's Encrypt or Self-signed)
# - Server name conflict detection
# - aaPanel integration support
# - Comprehensive logging and debugging
# - Auto-renewal setup for Let's Encrypt

set -e

# Configuration
NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
LOG_DIR="/var/log/nginx"
SSL_DIR="/etc/ssl/certs"
SSL_KEY_DIR="/etc/ssl/private"
CERTBOT_AVAILABLE=false

# Check if certbot is available
if command -v certbot &> /dev/null; then
    CERTBOT_AVAILABLE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate self-signed certificate
generate_self_signed_cert() {
    local domain=$1
    local cert_file="$SSL_DIR/$domain.crt"
    local key_file="$SSL_KEY_DIR/$domain.key"
    
    print_status "Generating self-signed SSL certificate for $domain"
    
    # Create directories if they don't exist
    mkdir -p "$SSL_DIR" "$SSL_KEY_DIR"
    
    # Generate certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$domain/emailAddress=admin@$domain" \
        -addext "subjectAltName=DNS:$domain,DNS:www.$domain"
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    print_status "Self-signed certificate generated: $cert_file"
}

# Function to generate Let's Encrypt certificate
generate_letsencrypt_cert() {
    local domain=$1
    
    print_status "Generating Let's Encrypt SSL certificate for $domain"
    
    # Check if certbot is available
    if ! $CERTBOT_AVAILABLE; then
        print_warning "Certbot not found. Installing certbot..."
        apt-get update && apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Stop nginx temporarily for standalone mode
    systemctl stop nginx
    
    # Generate certificate
    if certbot certonly --standalone -d "$domain" -d "www.$domain" --agree-tos --non-interactive --email "admin@$domain"; then
        print_status "Let's Encrypt certificate generated successfully"
        
        # Start nginx back
        systemctl start nginx
        return 0
    else
        print_error "Let's Encrypt certificate generation failed"
        systemctl start nginx
        return 1
    fi
}

# Function to check if domain points to this server
check_domain_dns() {
    local domain=$1
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || wget -qO- ifconfig.me 2>/dev/null || echo "unknown")
    
    print_status "Checking DNS for $domain (Server IP: $server_ip)"
    
    # Try to resolve domain
    if command -v dig &> /dev/null; then
        local domain_ip=$(dig +short "$domain" 2>/dev/null | tail -n1)
        if [ "$domain_ip" = "$server_ip" ]; then
            print_status "✅ DNS check passed: $domain points to this server"
            return 0
        else
            print_warning "⚠️  DNS check: $domain points to $domain_ip, server IP is $server_ip"
            return 1
        fi
    else
        print_warning "dig command not found, skipping DNS check"
        return 1
    fi
}
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get parameters
DOMAIN=$1
APACHE_PORT=${2:-8080}
SSL_ENABLED=${3:-false}

# Validate input
if [ -z "$DOMAIN" ]; then
    print_error "Usage: $0 <domain.com> [apache_port] [ssl|letsencrypt|self]"
    print_error "Examples:"
    print_error "  $0 mysite.com 8080"
    print_error "  $0 mysite.com 8080 self          # Self-signed SSL"
    print_error "  $0 mysite.com 8080 letsencrypt   # Let's Encrypt SSL"
    print_error "  $0 mysite.com 8080 true          # Self-signed SSL (backward compatibility)"
    exit 1
fi

# Determine SSL type
SSL_TYPE="none"
if [ "$SSL_ENABLED" = "true" ] || [ "$SSL_ENABLED" = "self" ]; then
    SSL_TYPE="self"
    SSL_ENABLED=true
elif [ "$SSL_ENABLED" = "letsencrypt" ] || [ "$SSL_ENABLED" = "le" ]; then
    SSL_TYPE="letsencrypt"
    SSL_ENABLED=true
else
    SSL_ENABLED=false
fi

# Clean domain name
CLEAN_DOMAIN=$(echo $DOMAIN | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]//g')
CONFIG_FILE="$NGINX_SITES_DIR/$CLEAN_DOMAIN"

print_status "Creating reverse proxy configuration for $DOMAIN"
print_status "Apache port: $APACHE_PORT"
print_status "SSL enabled: $SSL_ENABLED ($SSL_TYPE)"

# Check if Apache is running on specified port
if ! nc -z localhost $APACHE_PORT 2>/dev/null; then
    print_warning "⚠️  Apache doesn't seem to be running on port $APACHE_PORT"
    print_warning "   Please make sure your Apache/aaPanel site is configured for port $APACHE_PORT"
fi

# Create the HTTP configuration first
cat > $CONFIG_FILE << EOF
# Reverse proxy configuration for $DOMAIN
# Generated on $(date)
# Apache backend: 127.0.0.1:$APACHE_PORT

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Logging
    access_log $LOG_DIR/$CLEAN_DOMAIN.access.log;
    error_log $LOG_DIR/$CLEAN_DOMAIN.error.log;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
EOF

# Add SSL redirect or main content based on SSL setting
if [ "$SSL_ENABLED" = "true" ]; then
    cat >> $CONFIG_FILE << EOF
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS configuration
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL Configuration
    ssl_certificate $SSL_DIR/$CLEAN_DOMAIN.crt;
    ssl_certificate_key $SSL_KEY_DIR/$CLEAN_DOMAIN.key;
    
    # SSL Security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Logging
    access_log $LOG_DIR/$CLEAN_DOMAIN.ssl.access.log;
    error_log $LOG_DIR/$CLEAN_DOMAIN.ssl.error.log;
EOF
else
    cat >> $CONFIG_FILE << EOF
EOF
fi

# Add main proxy configuration (same for both HTTP and HTTPS)
cat >> $CONFIG_FILE << EOF
    
    # Main proxy location
    location / {
        # Proxy to Apache
        proxy_pass http://127.0.0.1:$APACHE_PORT;
        
        # Headers for backend - CRITICAL for proper domain handling
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Original-URI \$request_uri;
        
        # Connection settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings for better performance
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 16 8k;
        proxy_busy_buffers_size 16k;
        
        # Handle redirects properly - IMPORTANT
        proxy_redirect http://127.0.0.1:$APACHE_PORT/ \$scheme://\$host/;
        proxy_redirect http://127.0.0.1:$APACHE_PORT \$scheme://\$host;
        
        # Support for websockets (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Ensure proper handling of server name
        proxy_ssl_server_name on;
    }
    
    # Optimize static file serving
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf|zip|tar|gz|webp|avif)$ {
        proxy_pass http://127.0.0.1:$APACHE_PORT;
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Served-By "nginx-proxy";
    }
    
    # Handle WordPress/PHP admin areas with longer timeouts
    location ~ ^/(wp-admin|wp-login|admin|dashboard|xmlrpc\.php) {
        proxy_pass http://127.0.0.1:$APACHE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Longer timeouts for admin operations
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    # Security: Block access to sensitive files
    location ~ /\.(ht|env|git) {
        deny all;
        return 404;
    }
    
    # Handle PHP files specifically
    location ~ \.php$ {
        proxy_pass http://127.0.0.1:$APACHE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Generate SSL certificate if requested
if [ "$SSL_ENABLED" = "true" ]; then
    case $SSL_TYPE in
        "letsencrypt")
            # Try Let's Encrypt first
            if check_domain_dns "$DOMAIN"; then
                if generate_letsencrypt_cert "$DOMAIN"; then
                    # Update SSL paths for Let's Encrypt
                    sed -i "s|$SSL_DIR/$CLEAN_DOMAIN.crt|/etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" "$CONFIG_FILE"
                    sed -i "s|$SSL_KEY_DIR/$CLEAN_DOMAIN.key|/etc/letsencrypt/live/$DOMAIN/privkey.pem|g" "$CONFIG_FILE"
                else
                    print_warning "Let's Encrypt failed, falling back to self-signed certificate"
                    generate_self_signed_cert "$CLEAN_DOMAIN"
                fi
            else
                print_warning "DNS doesn't point to this server, using self-signed certificate"
                generate_self_signed_cert "$CLEAN_DOMAIN"
            fi
            ;;
        "self")
            generate_self_signed_cert "$CLEAN_DOMAIN"
            ;;
    esac
fi

# Enable the site
if [ ! -L "$NGINX_ENABLED_DIR/$CLEAN_DOMAIN" ]; then
    ln -s "$CONFIG_FILE" "$NGINX_ENABLED_DIR/$CLEAN_DOMAIN"
    print_status "Site enabled: $CLEAN_DOMAIN"
else
    print_warning "Site already enabled: $CLEAN_DOMAIN"
    rm -f "$NGINX_ENABLED_DIR/$CLEAN_DOMAIN"
    ln -s "$CONFIG_FILE" "$NGINX_ENABLED_DIR/$CLEAN_DOMAIN"
    print_status "Site re-enabled: $CLEAN_DOMAIN"
fi

# Test nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t 2>/dev/null; then
    print_status "Nginx configuration test passed!"
    
    # Reload nginx
    print_status "Reloading Nginx..."
    systemctl reload nginx
    
    # Test the backend connection
    print_status "Testing backend connection..."
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$APACHE_PORT" | grep -q "200\|301\|302"; then
        print_status "✅ Backend Apache is responding on port $APACHE_PORT"
    else
        print_warning "⚠️  Backend Apache may not be responding properly on port $APACHE_PORT"
    fi
    
    print_status "✅ Reverse proxy setup completed successfully!"
    echo ""
    print_status "Your site should now be accessible at:"
    echo "  🌐 http://$DOMAIN"
    if [ "$SSL_ENABLED" = "true" ]; then
        echo "  🔒 https://$DOMAIN"
        if [ "$SSL_TYPE" = "letsencrypt" ]; then
            echo "     (Let's Encrypt SSL)"
        else
            echo "     (Self-signed SSL - browsers will show security warning)"
        fi
    fi
    echo ""
    print_status "Backend Apache server: http://127.0.0.1:$APACHE_PORT"
    echo ""
    print_status "Log files:"
    echo "  📄 Access: $LOG_DIR/$CLEAN_DOMAIN.access.log"
    echo "  ❌ Error:  $LOG_DIR/$CLEAN_DOMAIN.error.log"
    if [ "$SSL_ENABLED" = "true" ]; then
        echo "  🔒 SSL Access: $LOG_DIR/$CLEAN_DOMAIN.ssl.access.log"
        echo "  🔒 SSL Error:  $LOG_DIR/$CLEAN_DOMAIN.ssl.error.log"
    fi
    
else
    print_error "Nginx configuration test failed!"
    print_error "Please check the configuration file: $CONFIG_FILE"
    print_error "Error details:"
    nginx -t
    exit 1
fi

# Show status and debugging info
echo ""
print_status "🔍 Debugging Information:"
echo "📁 Config file: $CONFIG_FILE"
echo "🔗 Symlink: $NGINX_ENABLED_DIR/$CLEAN_DOMAIN"
echo "🔄 Active sites: $(ls -1 $NGINX_ENABLED_DIR | wc -l)"

# Check server name conflicts
print_status "Checking for server name conflicts..."
CONFLICTS=$(grep -r "server_name.*$DOMAIN" /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "$CLEAN_DOMAIN" || true)
if [ -n "$CONFLICTS" ]; then
    print_warning "⚠️  Found potential server name conflicts:"
    echo "$CONFLICTS"
    print_warning "   This might cause the domain to serve wrong content"
fi

# Additional tips
echo ""
print_status "💡 Troubleshooting Tips:"
echo "  🔧 To disable this site: sudo rm $NGINX_ENABLED_DIR/$CLEAN_DOMAIN && sudo nginx -s reload"
echo "  📝 To edit config: sudo nano $CONFIG_FILE"
echo "  📊 To view logs: sudo tail -f $LOG_DIR/$CLEAN_DOMAIN.access.log"
echo "  🔍 Test backend directly: curl -I http://127.0.0.1:$APACHE_PORT"
echo "  🌐 Test frontend: curl -I http://$DOMAIN"

# Check aaPanel configuration
echo ""
print_status "📋 aaPanel Configuration Check:"
if [ -d "/www/wwwroot/$DOMAIN" ]; then
    print_status "✅ Found aaPanel site directory: /www/wwwroot/$DOMAIN"
    if [ -f "/www/wwwroot/$DOMAIN/index.php" ] || [ -f "/www/wwwroot/$DOMAIN/index.html" ]; then
        print_status "✅ Found index file in site directory"
    else
        print_warning "⚠️  No index.php or index.html found in /www/wwwroot/$DOMAIN"
    fi
else
    print_warning "⚠️  aaPanel site directory not found: /www/wwwroot/$DOMAIN"
    print_warning "   Make sure to create the site in aaPanel with domain: $DOMAIN"
fi

# Final verification
echo ""
print_status "🧪 Final Verification:"
echo "Run these commands to verify everything is working:"
echo "  curl -H 'Host: $DOMAIN' http://127.0.0.1:$APACHE_PORT"
echo "  curl -I http://$DOMAIN"
if [ "$SSL_ENABLED" = "true" ]; then
    echo "  curl -I https://$DOMAIN"
fi

# Auto-renewal setup for Let's Encrypt
if [ "$SSL_TYPE" = "letsencrypt" ] && [ "$SSL_ENABLED" = "true" ]; then
    print_status "Setting up auto-renewal for Let's Encrypt certificate..."
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        print_status "✅ Auto-renewal cron job added"
    else
        print_status "ℹ️  Auto-renewal already configured"
    fi
fi

echo ""
echo "==================================================================================="
echo "🎉 Apache to Nginx Reverse Proxy Setup Complete!"
echo "==================================================================================="
echo "📧 Script created by: Bhushan Barbuddhe"
echo "📅 Generated on: $(date)"
echo "🔧 Configuration: $DOMAIN → Apache:$APACHE_PORT"
if [ "$SSL_ENABLED" = "true" ]; then
    echo "🔒 SSL: Enabled ($SSL_TYPE)"
fi
echo "==================================================================================="