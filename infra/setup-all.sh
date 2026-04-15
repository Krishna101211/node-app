#!/bin/bash
set -euo pipefail

echo "=== Complete Infrastructure Setup ==="
echo "This script runs all setup steps in order."
echo ""

REGION="${AWS_REGION:-us-east-1}"
ENV_NAME="${1:-production}"
YOUR_IP="${2:?Usage: $0 <env-name> <your-ip/32>}"

echo "Environment: $ENV_NAME"
echo "Region: $REGION"
echo "Your IP: $YOUR_IP"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 1
fi

echo ""
echo "=== Step 1: IAM Roles ==="
bash "$(dirname "$0")/setup-iam.sh" "$ENV_NAME"

echo ""
echo "=== Step 2: S3 Bucket ==="
bash "$(dirname "$0")/setup-s3.sh" "my-app-build-artifacts"

echo ""
echo "=== Step 3: VPC & Networking ==="
bash "$(dirname "$0")/setup-vpc.sh" "$ENV_NAME"

VPC_ID=$(sed -n '1p' /tmp/${ENV_NAME}-vpc-id.txt)

echo ""
echo "=== Step 4: Security Group ==="
bash "$(dirname "$0")/setup-security-group.sh" "$VPC_ID" "$ENV_NAME" "$YOUR_IP"

echo ""
echo "=== Step 5: EC2 Instance ==="
bash "$(dirname "$0")/setup-ec2.sh" "$ENV_NAME"

echo ""
echo "========================================="
echo "  INFRASTRUCTURE SETUP COMPLETE"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. SSH into the instance: $(cat /tmp/${ENV_NAME}-instance.txt | grep SSH | cut -d' ' -f2-)"
echo "  2. Verify: node --version, pm2 --version, nginx -v"
echo "  3. Store secrets in SSM: aws ssm put-parameter --name /my-app/production/db-password --value 'xxx' --type SecureString"
echo "  4. Push code to GitHub to trigger first deployment"
echo ""
