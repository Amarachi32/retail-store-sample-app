# PowerShell script to initialize S3 bucket and DynamoDB table for Terraform Remote State
# Run this ONCE before 'terraform init'

$STUDENT_ID = "alt-soe-025-0959"
$BUCKET_NAME = "terraform-state-bedrock-$STUDENT_ID"
$TABLE_NAME = "terraform-state-locking"
$REGION = "us-east-1"

Write-Host "Creating S3 Bucket: $BUCKET_NAME..."
aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION

# Note: Versioning skipped to reduce cost as requested.

Write-Host "Creating DynamoDB Table: $TABLE_NAME with minimal throughput..."
aws dynamodb create-table `
    --table-name $TABLE_NAME `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 `
    --region $REGION

Write-Host "Done! Backend resources created."
