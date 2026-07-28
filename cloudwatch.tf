# ================================
# SNS Topic (EXISTING - LOOKUP)
# ================================
data "aws_sns_topic" "alerts" {
  name = "Secure-Health-dev-4e5b5469-alerts"
}

# ================================
# SNS Topic Policy
# ================================
resource "aws_sns_topic_policy" "allow_cloudwatch_and_eventbridge" {
  arn = data.aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow_CloudWatch_Alarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = data.aws_sns_topic.alerts.arn
      },
      {
        Sid    = "Allow_EventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = data.aws_sns_topic.alerts.arn
      }
    ]
  })
}

# ================================
# SECURITY ALARMS
# ================================

resource "aws_cloudwatch_metric_alarm" "unauthorized_api" {
  alarm_name          = "${var.project_name}-01-UnauthorizedAPI"
  alarm_description   = "Unauthorized AWS API calls detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "${var.project_name}-02-RootLogin"
  alarm_description   = "Root account login detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountLogins"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "${var.project_name}-03-IAMChanges"
  alarm_description   = "IAM policy changes detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "sg_changes" {
  alarm_name          = "${var.project_name}-04-SGChanges"
  alarm_description   = "Security group changes detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "s3_policy_changes" {
  alarm_name          = "${var.project_name}-05-S3PolicyChange"
  alarm_description   = "S3 bucket policy changed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "S3PolicyChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_changes" {
  alarm_name          = "${var.project_name}-06-CloudTrailStopped"
  alarm_description   = "CloudTrail logging disabled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CloudTrailChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "no_mfa_login" {
  alarm_name          = "${var.project_name}-07-LoginNoMFA"
  alarm_description   = "Console login without MFA"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ConsoleLoginNoMFA"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "failed_login" {
  alarm_name          = "${var.project_name}-08-FailedLogins"
  alarm_description   = "Multiple failed console logins"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedConsoleLogins"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "3"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_delete" {
  alarm_name          = "${var.project_name}-09-DynamoDBDeleted"
  alarm_description   = "DynamoDB table changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "DynamoDBTableChanges"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_stopped" {
  alarm_name          = "${var.project_name}-10-EC2Stopped"
  alarm_description   = "EC2 instance stopped or terminated"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "EC2StateChange"
  namespace           = "${var.project_name}/SecurityMetrics"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

# ================================
# APPLICATION ALARMS
# ================================

resource "aws_cloudwatch_metric_alarm" "patient_admitted" {
  alarm_name          = "${var.project_name}-11-PatientAdmitted"
  alarm_description   = "New patient admitted"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "PatientAdmitted"
  namespace           = "SecureHealth/Patients"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "critical_patient_admitted" {
  alarm_name          = "${var.project_name}-12-CriticalPatient"
  alarm_description   = "Critical patient admitted"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "PatientAdmitted"
  namespace           = "SecureHealth/Patients"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]

  dimensions = {
    Status = "Critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "patient_deleted" {
  alarm_name          = "${var.project_name}-13-PatientDeleted"
  alarm_description   = "Patient record deleted"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "PatientDeleted"
  namespace           = "SecureHealth/Patients"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
}