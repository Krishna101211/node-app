#!/bin/bash
set -euo pipefail

ENV_NAME="${1:-production}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Destroying ${ENV_NAME} Infrastructure ==="
echo "Account: $ACCOUNT_ID"
echo ""

read -p "This will DELETE all resources for ${ENV_NAME}. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 0
fi

echo "[1/5] Terminating EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=${ENV_NAME}" "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
  echo "Instance $INSTANCE_ID terminating..."
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
  echo "Instance terminated"
else
  echo "No running instances found"
fi

echo "[2/5] Deleting security groups..."
SG_IDS=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Environment,Values=${ENV_NAME}" \
  --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")

for SG_ID in $SG_IDS; do
  if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null && echo "Deleted SG: $SG_ID" || echo "Cannot delete SG: $SG_ID (may have dependencies)"
  fi
done

echo "[3/5] Deleting IAM roles..."
for ROLE in "${ENV_NAME}-EC2DeploymentRole" "${ENV_NAME}-CodeBuildRole" "${ENV_NAME}-CodePipelineRole"; do
  aws iam remove-role-from-instance-profile \
    --instance-profile-name "${ENV_NAME}-EC2DeploymentProfile" \
    --role-name "$ROLE" 2>/dev/null || true

  POLICIES=$(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
  for POLICY in $POLICIES; do
    aws iam delete-role-policy --role-name "$ROLE" --policy-name "$POLICY" 2>/dev/null
  done

  ATTACHED=$(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
  for ARN in $ATTACHED; do
    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$ARN" 2>/dev/null
  done

  aws iam delete-role --role-name "$ROLE" 2>/dev/null && echo "Deleted role: $ROLE" || echo "Role $ROLE not found or cannot be deleted"
done

aws iam delete-instance-profile --instance-profile-name "${ENV_NAME}-EC2DeploymentProfile" 2>/dev/null || true

echo "[4/5] Deleting VPC resources..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=${ENV_NAME}" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")

  if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null
    echo "Deleted IGW: $IGW_ID"
  fi

  RT_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Associations==`[]`].RouteTableId' --output text 2>/dev/null || echo "")

  for RT_ID in $RT_IDS; do
    if [ "$RT_ID" != "None" ] && [ -n "$RT_ID" ]; then
      aws ec2 delete-route-table --route-table-id "$RT_ID" 2>/dev/null && echo "Deleted RT: $RT_ID"
    fi
  done

  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")

  for SUBNET_ID in $SUBNET_IDS; do
    if [ "$SUBNET_ID" != "None" ] && [ -n "$SUBNET_ID" ]; then
      aws ec2 delete-subnet --subnet-id "$SUBNET_ID" 2>/dev/null && echo "Deleted Subnet: $SUBNET_ID"
    fi
  done

  aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null && echo "Deleted VPC: $VPC_ID"
fi

echo "[5/5] S3 bucket (manual)..."
echo "WARNING: S3 bucket my-app-build-artifacts is NOT deleted automatically."
echo "To delete manually: aws s3 rb s3://my-app-build-artifacts --force"

rm -f /tmp/${ENV_NAME}-*.txt

echo ""
echo "=== Teardown Complete ==="
