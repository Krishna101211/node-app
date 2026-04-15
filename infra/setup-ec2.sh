#!/bin/bash
set -euo pipefail

ENV_NAME="${1:-production}"
REGION="${AWS_REGION:-us-east-1}"

if [ ! -f "/tmp/${ENV_NAME}-vpc-id.txt" ]; then
  echo "ERROR: Run setup-vpc.sh first"
  exit 1
fi

VPC_ID=$(sed -n '1p' /tmp/${ENV_NAME}-vpc-id.txt)
SUBNET_ID=$(sed -n '2p' /tmp/${ENV_NAME}-vpc-id.txt)

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ]; then
  echo "ERROR: VPC_ID or SUBNET_ID not found"
  exit 1
fi

SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${ENV_NAME}-app-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  echo "ERROR: Security group ${ENV_NAME}-app-sg not found. Run setup-security-group.sh first."
  exit 1
fi

KEY_NAME="${ENV_NAME}-deploy-key"
KEY_FILE="${KEY_NAME}.pem"

aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query 'KeyMaterial' --output text > "$KEY_FILE" 2>/dev/null || {
  echo "Key pair $KEY_NAME already exists, skipping creation"
  if [ ! -f "$KEY_FILE" ]; then
    echo "WARNING: Key file $KEY_FILE not found locally. You may need to retrieve it."
  fi
}

chmod 400 "$KEY_FILE" 2>/dev/null || true

echo "=== Launching EC2 Instance ==="
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "Security Group: $SG_ID"
echo "Key: $KEY_NAME"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.medium \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --iam-instance-profile Name="${ENV_NAME}-EC2DeploymentProfile" \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=30,VolumeType=gp3,Encrypted=true}" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=${ENV_NAME}-app-server},{Key=Environment,Value=${ENV_NAME}}]" \
    "ResourceType=volume,Tags=[{Key=Name,Value=${ENV_NAME}-app-volume},{Key=Environment,Value=${ENV_NAME}}]" \
  --user-data file://user-data.sh \
  --query 'Instances[0].InstanceId' --output text)

echo "Instance launching: $INSTANCE_ID"

echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo "=== EC2 Instance Ready ==="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $INSTANCE_IP"
echo "SSH: ssh -i $KEY_FILE ec2-user@$INSTANCE_IP"
echo ""
echo "Save these values:"
echo "INSTANCE_ID=$INSTANCE_ID" > /tmp/${ENV_NAME}-instance.txt
echo "INSTANCE_IP=$INSTANCE_IP" >> /tmp/${ENV_NAME}-instance.txt
echo "KEY_FILE=$KEY_FILE" >> /tmp/${ENV_NAME}-instance.txt
