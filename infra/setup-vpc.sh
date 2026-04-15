#!/bin/bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ENV_NAME="${1:-production}"

echo "=== Creating VPC & Networking ==="
echo "Region: $REGION"
echo "Environment: $ENV_NAME"

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${ENV_NAME}-vpc},{Key=Environment,Value=${ENV_NAME}}]" \
  --query 'Vpc.VpcId' --output text)

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames

echo "VPC created: $VPC_ID"

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${ENV_NAME}-public-subnet},{Key=Environment,Value=${ENV_NAME}}]" \
  --query 'Subnet.SubnetId' --output text)

echo "Subnet created: $SUBNET_ID"

IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${ENV_NAME}-igw},{Key=Environment,Value=${ENV_NAME}}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "Internet Gateway created: $IGW_ID"

RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${ENV_NAME}-rt},{Key=Environment,Value=${ENV_NAME}}]" \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID"
echo "Route table created: $RT_ID"

aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch

echo ""
echo "=== VPC Setup Complete ==="
echo "VPC_ID=$VPC_ID"
echo "SUBNET_ID=$SUBNET_ID"
echo "IGW_ID=$IGW_ID"
echo "RT_ID=$RT_ID"

echo "$VPC_ID" > /tmp/${ENV_NAME}-vpc-id.txt
echo "$SUBNET_ID" >> /tmp/${ENV_NAME}-vpc-id.txt
