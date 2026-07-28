# variables.tf

# ─────────────────────────────────────────
# AWS Configuration
# ─────────────────────────────────────────

variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-2"
}

variable "aws_account_id" {
  type        = string
  description = "Your 12 digit AWS account ID"
  sensitive   = true
}

# ─────────────────────────────────────────
# Project Configuration
# ─────────────────────────────────────────

variable "project_name" {
  type        = string
  description = "Project name used in all resource names"
  default     = "Secure-Health"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ─────────────────────────────────────────
# Security & Access
# ─────────────────────────────────────────

variable "my_ip" {
  type        = string
  description = "Your local IP address for SSH — get from whatismyip.com"
}

variable "alert_email" {
  type        = string
  description = "Email address to receive CloudWatch security alerts"
}

# ─────────────────────────────────────────
# SSH Keys
# ─────────────────────────────────────────

variable "ssh_public_key_path" {
  type        = string
  description = "Path to your SSH public key — uploaded to AWS"
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  type        = string
  description = "Path to your SSH private key — used to copy website files to EC2"
  default     = "~/.ssh/id_rsa"
}