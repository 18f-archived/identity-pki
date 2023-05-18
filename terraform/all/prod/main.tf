provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["555546682965"] # require login-prod
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

variable "splunk_oncall_cloudwatch_endpoint" {
  default = "UNSET"
}

variable "splunk_oncall_newrelic_endpoint" {
  default = "UNSET"
}

module "main" {
  source            = "../module"
  iam_account_alias = "login-prod"

  slack_events_sns_topic            = "slack-events"
  splunk_oncall_cloudwatch_endpoint = var.splunk_oncall_cloudwatch_endpoint
  splunk_oncall_newrelic_endpoint   = var.splunk_oncall_newrelic_endpoint

  dnssec_zone_exists = true

  reports_bucket_arn = "arn:aws:s3:::login-gov.reports.555546682965-us-west-2"
  ses_email_limit    = 500000
  account_roles_map = {
    iam_reports_enabled        = true
    iam_kmsadmin_enabled       = true
    iam_analytics_enabled      = true
    iam_auto_terraform_enabled = false
    iam_supporteng_enabled     = true
    iam_fraudops_enabled       = true
  }

  guardduty_usw2_soc_enabled = true  # previously created in terraform/core
  guardduty_use1_soc_enabled = false # confirm destination exists before enabling

  legacy_bucket_list = [
    "login-gov-logs-prod.555546682965-us-west-2",
    "login-gov-logs-staging.555546682965-us-west-2",
    "login-gov-prod-analytics",
    "login-gov-global-trail",
    "login-gov.waf-logs.555546682965-us-west-2",
  ]

  cloudtrail_event_selectors = [
    {
      include_management_events = false
      read_write_type           = "WriteOnly"

      data_resources = [
        {
          type = "AWS::S3::Object"
          values = [
            "arn:aws:s3:::config-bucket-555546682965/",
            "arn:aws:s3:::configruleslogingov/",
            "arn:aws:s3:::login-dot-gov-security-logs/",
            "arn:aws:s3:::login-gov-backup/",
            "arn:aws:s3:::login-gov-cloudtrail-555546682965/",
            "arn:aws:s3:::login-gov-dev-logs/",
            "arn:aws:s3:::login-gov-dm-logs/",
            "arn:aws:s3:::login-gov-elasticsearch-dm.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-elasticsearch-prod.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-elasticsearch-staging.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-fraud-models/",
            "arn:aws:s3:::login-gov-global-trail/",
            "arn:aws:s3:::login-gov-int-logs/",
            "arn:aws:s3:::login-gov-int-logs-bak/",
            "arn:aws:s3:::login-gov-internal-certs-test-us-west-2-555546682965/",
            "arn:aws:s3:::login-gov-internal-certs-test-us-west-2-555546682965-logs/",
            "arn:aws:s3:::login-gov-proxylogs-dm.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-proxylogs-int.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-proxylogs-prod.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-proxylogs-staging.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov-qa-chefstuff/",
            "arn:aws:s3:::login-gov-qa-logs/",
            "arn:aws:s3:::login-gov-secrets-test/",
            "arn:aws:s3:::login-gov-shared-data-555546682965/",
            "arn:aws:s3:::login-gov-staging-logs/",
            "arn:aws:s3:::login-gov-testing/",
            "arn:aws:s3:::login-gov-tspencer-logs/",
            "arn:aws:s3:::login-gov-tspencer-secrets/",
            "arn:aws:s3:::login-gov.elb-logs.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov.email.555546682965-us-west-2/",
            "arn:aws:s3:::login-gov.s3-access-logs.555546682965-us-west-2/",
            "arn:aws:s3:::tf-fraud-bucket-depployments/",
          ]
        },
      ]
    },
    {
      include_management_events = true
      read_write_type           = "All"

      data_resources = [
        {
          type = "AWS::S3::Object"
          values = [
            "arn:aws:s3:::555546682965-awsmacietrail-dataevent/",
            "arn:aws:s3:::aws-athena-query-results-555546682965-us-west-2/",
            "arn:aws:s3:::aws-glue-scripts-555546682965-us-west-2/",
            "arn:aws:s3:::aws-glue-temporary-555546682965-us-west-2/",
            "arn:aws:s3:::cf-templates-iccjd8v5q7bo-us-west-2/",
            "arn:aws:s3:::lgoin-gov.super-secrets/",
            "arn:aws:s3:::login-gov.shared-secrets/",
            "arn:aws:s3:::login-gov.super-secrets/",
          ]
        },
      ]
    },
  ]

  ssm_document_access_map = {
    "FullAdministrator" = [{ "*" = ["*"] }],
    "PowerUser"         = [{ "*" = ["*"] }],
    "SupportEngineer"   = [{ "*" = ["uuid-lookup"] }],
    # "Terraform"         = [{ "*" = ["*"] }], This will need to be specific before enabling
    "FraudOps" = [{ "*" = ["review-pass", "review-reject", "uuid-lookup"] }],
  }

  ssm_command_access_map = {
    "FullAdministrator" = [{ "*" = ["*"] }],
    "PowerUser"         = [{ "*" = ["*"] }],
    "SupportEngineer"   = [],
    # "Terraform"         = [{ "*" = ["*"] }], This will need to be specific before enabling
    "FraudOps" = [{ "*" = ["data-pull"] }],
  }
}
