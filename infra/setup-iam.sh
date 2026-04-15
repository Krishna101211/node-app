#!/bin/bash
set -euo pipefail

ENV_NAME="${1:-production}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Creating IAM Roles ==="
echo "Account: $ACCOUNT_ID"
echo "Environment: $ENV_NAME"

cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "${ENV_NAME}-EC2DeploymentRole" \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
  2>/dev/null || echo "Role ${ENV_NAME}-EC2DeploymentRole already exists"

cat > /tmp/ec2-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-app-build-artifacts",
        "arn:aws:s3:::my-app-build-artifacts/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
      "Resource": "arn:aws:ssm:*:${ACCOUNT_ID}:parameter/my-app/*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"],
      "Resource": "arn:aws:logs:*:${ACCOUNT_ID}:log-group:/my-app/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "${ENV_NAME}-EC2DeploymentRole" \
  --policy-name "${ENV_NAME}-EC2AccessPolicy" \
  --policy-document file:///tmp/ec2-policy.json

aws iam create-instance-profile \
  --instance-profile-name "${ENV_NAME}-EC2DeploymentProfile" 2>/dev/null || true

aws iam add-role-to-instance-profile \
  --instance-profile-name "${ENV_NAME}-EC2DeploymentProfile" \
  --role-name "${ENV_NAME}-EC2DeploymentRole" 2>/dev/null || true

echo ""
echo "=== EC2 IAM Roles Created ==="
echo "Role: ${ENV_NAME}-EC2DeploymentRole"
echo "Instance Profile: ${ENV_NAME}-EC2DeploymentProfile"

cat > /tmp/codebuild-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "codebuild.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "${ENV_NAME}-CodeBuildRole" \
  --assume-role-policy-document file:///tmp/codebuild-trust-policy.json \
  2>/dev/null || echo "Role ${ENV_NAME}-CodeBuildRole already exists"

aws iam attach-role-policy \
  --role-name "${ENV_NAME}-CodeBuildRole" \
  --policy-arn arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess

cat > /tmp/codebuild-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-app-build-artifacts",
        "arn:aws:s3:::my-app-build-artifacts/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:*:*:parameter/my-app/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "${ENV_NAME}-CodeBuildRole" \
  --policy-name "${ENV_NAME}-CodeBuildS3Policy" \
  --policy-document file:///tmp/codebuild-policy.json

echo "CodeBuild Role: ${ENV_NAME}-CodeBuildRole"

cat > /tmp/codepipeline-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "codepipeline.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "${ENV_NAME}-CodePipelineRole" \
  --assume-role-policy-document file:///tmp/codepipeline-trust-policy.json \
  2>/dev/null || echo "Role ${ENV_NAME}-CodePipelineRole already exists"

aws iam attach-role-policy \
  --role-name "${ENV_NAME}-CodePipelineRole" \
  --policy-arn arn:aws:iam::aws:policy/AWSCodePipelineServiceRole

aws iam attach-role-policy \
  --role-name "${ENV_NAME}-CodePipelineRole" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name "${ENV_NAME}-CodePipelineRole" \
  --policy-arn arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess

echo "CodePipeline Role: ${ENV_NAME}-CodePipelineRole"

rm -f /tmp/ec2-trust-policy.json /tmp/ec2-policy.json
rm -f /tmp/codebuild-trust-policy.json /tmp/codebuild-policy.json
rm -f /tmp/codepipeline-trust-policy.json

echo ""
echo "=== All IAM Roles Created ==="
