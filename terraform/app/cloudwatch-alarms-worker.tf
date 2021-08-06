resource "aws_cloudwatch_metric_alarm" "idp_worker_alive_alarm" {
  count = var.idp_worker_alarms_enabled

  alarm_name                = "${var.env_name} IDP Workers Alive Alert"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "6"
  datapoints_to_alarm       = "6"
  metric_name               = "perform-success"
  namespace                 = "${var.env_name}/idp-worker"
  period                    = "60" # 6 minutes because heartbeat job is queued every 5 minutes, and queue is checked every 5 seconds
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "This alarm is executed when no worker jobs have run for 6 minutes"
  treat_missing_data        = "breaching"
  insufficient_data_actions = []
  alarm_actions             = local.high_priority_alarm_actions
}

# There should be no failures, so alert on any failure
resource "aws_cloudwatch_metric_alarm" "idp_worker_failure_alarm" {
  count = var.idp_worker_alarms_enabled

  alarm_name                = "${var.env_name} IDP Workers Failure Alert"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  datapoints_to_alarm       = "1"
  metric_name               = "perform-failure"
  namespace                 = "${var.env_name}/idp-worker"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "This alarm is executed when a worker job fails"
  treat_missing_data        = "missing"
  insufficient_data_actions = []
  alarm_actions             = local.high_priority_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "idp_worker_queue_time_alarm" {
  count = var.idp_worker_alarms_enabled

  alarm_name                = "${var.env_name} IDP Workers Queue Time Alert"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  datapoints_to_alarm       = "1"
  metric_name               = "queue-time-milliseconds"
  namespace                 = "${var.env_name}/idp-worker"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "10000" # Job queue is checked every 5 seconds
  alarm_description         = "This alarm is executed when job queue time exceeds allowable limits"
  treat_missing_data        = "missing"
  insufficient_data_actions = []
  alarm_actions             = local.high_priority_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "idp_worker_perform_time_alarm" {
  count = var.idp_worker_alarms_enabled

  alarm_name                = "${var.env_name} IDP Workers Perform Time Alert"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  datapoints_to_alarm       = "1"
  metric_name               = "perform-time-milliseconds"
  namespace                 = "${var.env_name}/idp-worker"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "50000"
  alarm_description         = "This alarm is executed when job perform time exceeds allowable limits"
  treat_missing_data        = "missing"
  insufficient_data_actions = []
  alarm_actions             = local.high_priority_alarm_actions
}

