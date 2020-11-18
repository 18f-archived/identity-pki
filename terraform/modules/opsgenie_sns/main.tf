variable "region" {
  description = "Region the secrets bucket has been created in"
  default     = "us-west-2"
}

data "aws_caller_identity" "current" {
}

data "aws_s3_bucket_object" "opsgenie_sns_apikey" {
  bucket = "login-gov.secrets.${data.aws_caller_identity.current.account_id}-${var.region}"
  key    = "common/opsgenie_sns_apikey"
}

provider "aws" {
  alias = "usw2"
}

provider "aws" {
  alias = "use1"
}

## Terraform providers cannot be generated, so we need a separate block for each region,
## at least for now. TODO: look into using terragrunt / another application to iterate
## through regions, rather than duplicating the code.

## us-west-2

resource "aws_sns_topic" "opsgenie_alert_usw2" {
  provider = aws.usw2
  name = "opsgenie-alert"
}

resource "aws_sns_topic_subscription" "opsgenie_alert_usw2" {
  provider = aws.usw2
  topic_arn = aws_sns_topic.opsgenie_alert_usw2.arn
  endpoint_auto_confirms = true
  protocol  = "https"
  endpoint  = "https://api.opsgenie.com/v1/json/cloudwatchevents?apiKey=${data.aws_s3_bucket_object.opsgenie_sns_apikey.body}"
}

resource "aws_sns_topic" "opsgenie_alert_use1" {
  provider = aws.use1
  name = "opsgenie-alert"
}

resource "aws_sns_topic_subscription" "opsgenie_alert_use1" {
  provider = aws.use1
  topic_arn = aws_sns_topic.opsgenie_alert_use1.arn
  endpoint_auto_confirms = true
  protocol  = "https"
  endpoint  = "https://api.opsgenie.com/v1/json/cloudwatchevents?apiKey=${data.aws_s3_bucket_object.opsgenie_sns_apikey.body}"
}

output "usw2_sns_topic_arn" {
  description = "ARN of the SNS topic in US-WEST-2."
  value = aws_sns_topic.opsgenie_alert_usw2.arn
}

output "use1_sns_topic_arn" {
  description = "ARN of the SNS topic in US-EAST-1."
  value = aws_sns_topic.opsgenie_alert_use1.arn
}