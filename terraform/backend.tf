terraform {
  backend "s3" {
    bucket         = "terraform-state-bedrock-alt-soe-025-0959"
    key            = "project-bedrock/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"    # Create this manually first
    encrypt        = true
  }
}