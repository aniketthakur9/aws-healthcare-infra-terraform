# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
   
    bucket       = "health-secure-tfstate-405988826637"
    key          = "dev/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix — ensures unique names on every fresh deploy
resource "random_id" "suffix" {
  byte_length = 4
}

# ─────────────────────────────────────────
# S3 Bucket — stores all CloudTrail logs
# ─────────────────────────────────────────

resource "aws_s3_bucket" "logs" {
    bucket        = "logs-${var.aws_account_id}-${var.environment}-${random_id.suffix.hex}"
  force_destroy = false

  lifecycle {
    ignore_changes = [bucket]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}


resource "aws_dynamodb_table" "patients" {
  name         = "${var.project_name}-patients"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "patient_id"

  attribute {
    name = "patient_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
    # Uses AWS-managed KMS key — no extra key needed
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Compliance  = "HIPAA"
    ManagedBy   = "terraform"
  }
}
