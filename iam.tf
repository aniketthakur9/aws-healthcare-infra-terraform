# iam.tf

# ─────────────────────────────────────────────────────────────────
# IAM Role — CloudTrail → CloudWatch Logs
# ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name        = "${var.project_name}-ct-cw-${random_id.suffix.hex}"
  description = "Allows CloudTrail to write logs into CloudWatch Log Group"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Least-privilege: CloudTrail can only write to its own log group
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-ct-cw-policy-${random_id.suffix.hex}"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailWriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────
# IAM Role — EC2 instance (Flask app)
# ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ─── Policy 1: DynamoDB — only the patients table, only required actions ───────
resource "aws_iam_role_policy" "ec2_dynamodb_policy" {
  name = "${var.project_name}-ec2-dynamodb-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBPatientsTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",       # Add patient
          "dynamodb:GetItem",       # Get single patient (for delete check)
          "dynamodb:DeleteItem",    # Delete patient
          "dynamodb:Scan",          # List all patients
          "dynamodb:DescribeTable"  # Health check
        ]
        # Scoped to only the patients table — not all DynamoDB tables
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-patients"
      }
    ]
  })
}

# ─── Policy 2: S3 — only the logs bucket, only PutObject (write audit logs) ───
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${var.project_name}-ec2-s3-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3AuditLogsWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject"   # Write audit/backup records — NO read, NO delete
        ]
        # Scoped to only the logs bucket
        Resource = "${aws_s3_bucket.logs.arn}/*"
      }
    ]
  })
}

# ─── Policy 3: SNS — only the alerts topic, only Publish ──────────────────────
resource "aws_iam_role_policy" "ec2_sns_policy" {
  name = "${var.project_name}-ec2-sns-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSAlertsPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"    # Send alerts only — cannot create/delete topics
        ]
        # Scoped to only the alerts topic — not all SNS topics
      Resource = data.aws_sns_topic.alerts.arn
      }
    ]
  })
}

# ─── Policy 4: CloudWatch — only metrics for this project ─────────────────────
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name = "${var.project_name}-ec2-cloudwatch-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetricsPush"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"  # Push metrics only — cannot read/delete logs
        ]
        Resource = "*"   # PutMetricData does not support resource-level restrictions
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────
# Instance Profile — attaches the role to the EC2 instance
# ─────────────────────────────────────────────────────────────────

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}
