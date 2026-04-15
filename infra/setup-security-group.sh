#!/bin/bash
set -euo pipefail

VPC_ID="${1:?Usage: $0 <vpc-id>}"
ENV_NAME="${2:-production}"
YOUR_IP="${3:?Usage: $0 <vpc-id> <env> <your-ip/32>}"

echo "=== Creating Security Group ==="

SG_ID=$(aws ec2 create-security-group \
  --group-name "${ENV_NAME}-app-sg" \
  --description "Security group for Node.js app - ${ENV_NAME}" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${ENV_NAME}-app-sg},{Key=Environment,Value=${ENV_NAME}}]" \
  --query 'GroupId' --output text)

echo "Security Group created: $SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 22 \
  --cidr "$YOUR_IP" \
  --description "SSH from trusted IP"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0 \
  --description "HTTP"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 443 \
  --cidr 0.0.0.0/0 \
  --description "HTTPS"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 3000 \
  --source-group "$SG_ID" \
  --description "Internal app port (Nginx to PM2)"

echo "Security Group ID: $SG_ID"
echo "$SG_ID" > /tmp/${ENV_NAME}-sg-id.txt
