#!/bin/bash
set -euo pipefail

BUCKET_NAME="${1:-my-app-build-artifacts}"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Creating S3 Bucket for Build Artifacts ==="

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" 2>/dev/null || echo "Bucket already exists"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "Versioning: enabled"

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Encryption: AES256"

cat > /tmp/s3-lifecycle.json << 'EOF'
{
  "Rules": [
    {
      "ID": "CleanupOldBuilds",
      "Status": "Enabled",
      "Filter": { "Prefix": "builds/" },
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration file:///tmp/s3-lifecycle.json

echo "Lifecycle: builds/ cleanup after 90 days"

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Public access: blocked"

aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging 'TagSet=[{Key=Environment,Value=production},{Key=Purpose,Value=build-artifacts}]'

rm -f /tmp/s3-lifecycle.json

echo ""
echo "=== S3 Bucket Ready ==="
echo "Bucket: s3://$BUCKET_NAME"
