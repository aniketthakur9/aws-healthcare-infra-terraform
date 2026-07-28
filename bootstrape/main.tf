# bootstrape/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "aws_account_id" {
  type      = string
  sensitive = true
}

locals {
  bucket_name = "health-secure-tfstate-${var.aws_account_id}"
  table_name  = "health-secure-tf-lock"
}

# ─────────────────────────────────────────
# S3 Bucket — Terraform state storage
# ─────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  bucket        = local.bucket_name

  # ✅ IMPORTANT: allow destroy
  force_destroy = true

  # ❌ removed prevent_destroy
  lifecycle {
    ignore_changes = [bucket]
  }

  tags = {
    Name       = local.bucket_name
    Purpose    = "terraform-state"
    Compliance = "HIPAA"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    ignore_changes = [versioning_configuration]
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }

  lifecycle {
    ignore_changes = [rule]
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    ignore_changes = [
      block_public_acls,
      block_public_policy,
      ignore_public_acls,
      restrict_public_buckets
    ]
  }
}

# ─────────────────────────────────────────
# DynamoDB Table — State locking
# ─────────────────────────────────────────

resource "aws_dynamodb_table" "tflock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # ✅ allow destroy
  lifecycle {
    ignore_changes = [name]
  }

  tags = {
    Purpose = "terraform-state-lock"
  }
}

# ─────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────

output "state_bucket_name" {
  value       = aws_s3_bucket.tfstate.id
  description = "Copy this into backend bucket field"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tflock.name
  description = "Copy this into backend dynamodb_table field"
}