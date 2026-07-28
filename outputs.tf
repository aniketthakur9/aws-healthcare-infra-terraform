# outputs.tf

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "environment" {
  description = "Active environment"
  value       = var.environment
}

output "log_bucket_name" {
  description = "S3 bucket storing all CloudTrail logs"
  value       = aws_s3_bucket.logs.id
}

output "cloudtrail_name" {
  description = "CloudTrail trail name"
  value       = aws_cloudtrail.main.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving CloudTrail logs"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = data.aws_sns_topic.alerts.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.health_app.public_ip
}

output "health_app_url" {
  description = "Open this in browser to see your health app"
  value       = "http://${aws_instance.health_app.public_ip}"
}
output "flask_admin_url" {
  description = "Flask admin dashboard"
  value       = "http://${aws_instance.health_app.public_ip}:5000"
}