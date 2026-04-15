#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Bootstrap started at $(date) ==="

yum update -y
yum install -y git nginx curl wget jq unzip

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install 20.11.0
nvm alias default 20.11.0
nvm use default

npm install -g pm2

echo 'export NVM_DIR="$HOME/.nvm"' >> /etc/profile.d/nvm.sh
echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh
echo 'nvm use default > /dev/null 2>&1' >> /etc/profile.d/nvm.sh

mkdir -p /opt/app
mkdir -p /opt/app/releases
mkdir -p /opt/app/logs
chown -R ec2-user:ec2-user /opt/app

cp /opt/app/scripts/deploy.sh /opt/app/deploy.sh 2>/dev/null || true
chmod +x /opt/app/deploy.sh 2>/dev/null || true
chown -R ec2-user:ec2-user /opt/app

cat > /etc/nginx/conf.d/app.conf << 'NGINX_EOF'
upstream node_app {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name _;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;

    access_log /var/log/nginx/app_access.log;
    error_log /var/log/nginx/app_error.log;

    client_max_body_size 10M;

    location / {
        proxy_pass http://node_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }

    location /health {
        proxy_pass http://node_app;
        access_log off;
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
NGINX_EOF

systemctl start nginx
systemctl enable nginx

env PATH=$PATH:/home/ec2-user/.nvm/versions/node/$(ls /home/ec2-user/.nvm/versions/node/)/bin \
  /home/ec2-user/.nvm/versions/node/$(ls /home/ec2-user/.nvm/versions/node/)/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user

echo "=== Bootstrap completed at $(date) ==="
