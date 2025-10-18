# S3 bucket for Terraform state file storage for remote backend
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "kaustubh-terraform-project-state" 
  tags = {
    Name        = "Terraform State Bucket"
    Environment = "main"
    Action      = "DO NOT DELETE"
  }
}

# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"  # Or PROVISIONED, if you prefer
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S" # String
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "main"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.terraform_state_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
       sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}