#Monitor and notify AWS Service usage using Trusted Advisor Checks

module "limit_check_lambda" {
  source = "../../modules/monitor_svc_limit"

  refresher_schedule = var.refresher_schedule
  monitor_schedule   = var.monitor_schedule
  sns_topic          = [aws_sns_topic.slack_usw2["events"].arn]
}

#Monitor and notify KMS Symmetric calls usage
resource "aws_cloudwatch_metric_alarm" "kms_api" {
  alarm_name          = "kms_api_usage_alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "10"
  threshold           = "80"
  alarm_description   = <<EOM
KMS Symmetric Cryptographic API request rate has exceeded 80% of limit for:
Account: ${data.aws_caller_identity.current.account_id}
Region: ${var.region}

Runbook: https://gitlab.login.gov/lg/identity-devops/-/wikis/Runbook:-AWS-Service-Limits#kms-symmetric-key-api
EOM

  insufficient_data_actions = []
  actions_enabled           = "true"
  alarm_actions             = [aws_sns_topic.slack_usw2["events"].arn]

  metric_query {
    id          = "pct_utilization"
    expression  = "(usage_data/SERVICE_QUOTA(usage_data))*100"
    label       = "% Utilization"
    return_data = "true"
  }

  metric_query {
    id          = "usage_data"
    return_data = "false"
    metric {
      metric_name = "CallCount"
      namespace   = "AWS/Usage"
      period      = "60"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        Class    = "None"
        Resource = "CryptographicOperationsSymmetric"
        Service  = "KMS"
        Type     = "API"
      }
    }
  }
}

# Monitor CloudTrail logs and notify for any LimitExceededError message

resource "aws_cloudwatch_log_metric_filter" "api_throttling" {
  name           = "LimitExceededErrorMessage"
  log_group_name = "CloudTrail/DefaultLogGroup"
  pattern        = "{ (($.errorCode = \"*LimitExceeded\") || ($.errorCode = \"LimitExceededException\")) && $.userIdentity.arn != \"*PrismaCloudRole/redlock*\" }"
  metric_transformation {
    name       = "LimitExceededErrorMessage"
    namespace  = "CloudTrailMetrics/APIThrottling"
    value      = 1
    dimensions = {}
  }
  depends_on = [aws_cloudwatch_log_group.cloudtrail_default]
}

resource "aws_cloudwatch_metric_alarm" "api_throttling" {
  alarm_name          = "svc_limit_exceeded_error_message"
  alarm_description   = <<EOM
LimitExceeded messages found in CloudTrail - AWS API rate limiting occurring
Account: ${data.aws_caller_identity.current.account_id}
Region: ${var.region}

Runbook: https://gitlab.login.gov/lg/identity-devops/-/wikis/Runbook:-AWS-Service-Limits#limitexceeded-in-cloudtrail
EOM
  metric_name         = aws_cloudwatch_log_metric_filter.api_throttling.name
  threshold           = var.threshold
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = var.datapoints_to_alarm
  evaluation_periods  = var.evaluation_periods
  period              = var.period
  namespace           = "CloudTrailMetrics/APIThrottling"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.slack_usw2["events"].arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_email_send_limit" {
  alarm_name          = "ses_email_send_limit"
  alarm_description   = <<EOM
In danger of exceeding ${var.ses_email_limit} emails per 6 hours
Account: ${data.aws_caller_identity.current.account_id}
Region: ${var.region}

Runbook: https://gitlab.login.gov/lg/identity-devops/-/wikis/Runbook%3A-Email-and-SMTP#ses-send-limit
EOM
  metric_name         = "Send"
  threshold           = var.ses_email_limit
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  period              = 21600 # 6 hours
  namespace           = "AWS/SES"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.slack_usw2["events"].arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_email_bounce_rate" {
  count               = var.ses_bounce_rate_threshold > 0 ? 1 : 0
  alarm_name          = "ses_email_bounce_rate"
  alarm_description   = <<EOM
Our SES email bounce rate has exceeded ${format("%.1f", var.ses_bounce_rate_threshold * 100)}% in the last 1 hour.
Account: ${data.aws_caller_identity.current.account_id}
Region: ${var.region}

Runbook: https://gitlab.login.gov/lg/identity-devops/-/wikis/Runbook%3A-Email-and-SMTP#ses-reputation-bounce-rate
EOM
  metric_name         = "Reputation.BounceRate"
  threshold           = var.ses_bounce_rate_threshold
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  period              = 3600 # 1 hour
  namespace           = "AWS/SES"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.slack_usw2["events"].arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_email_complaint_rate" {
  count               = var.ses_complaint_rate_threshold > 0 ? 1 : 0
  alarm_name          = "ses_complaint_rate_threshold"
  alarm_description   = <<EOM
Our SES email bounce rate has exceeded ${format("%.1f", var.ses_complaint_rate_threshold * 100)}% in the last 2 hours.
Account: ${data.aws_caller_identity.current.account_id}
Region: ${var.region}

Runbook: https://gitlab.login.gov/lg/identity-devops/-/wikis/Runbook%3A-Email-and-SMTP#ses-reputation-complaint-rate
EOM
  metric_name         = "Reputation.ComplaintRate"
  threshold           = var.ses_complaint_rate_threshold
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 2
  evaluation_periods  = 2
  period              = 3600 # 1 hour
  namespace           = "AWS/SES"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.slack_usw2["events"].arn]
}
