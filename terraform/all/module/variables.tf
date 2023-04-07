locals {
  common_account_name = var.iam_account_alias == "login-master" ? "global" : replace(var.iam_account_alias, "login-", "")

  role_enabled_defaults = {
    iam_analytics_enabled      = false
    iam_power_enabled          = true
    iam_readonly_enabled       = true
    iam_socadmin_enabled       = true
    iam_terraform_enabled      = true
    iam_auto_terraform_enabled = true
    iam_billing_enabled        = true
    iam_reports_enabled        = false
    iam_kmsadmin_enabled       = false
    iam_supporteng_enabled     = false
    iam_fraudops_enabled       = false
  }

  ssm_cmd_map = {
    "default"           = ["*"]
    "sudo"              = ["*"]
    "rails-c"           = ["idp", "migration", "worker"]
    "rails-w"           = ["idp", "migration", "worker"]
    "tail-cw"           = ["*"]
    "uuid-lookup"       = ["idp", "migration", "worker"]
    "review-pass"       = ["idp", "migration", "worker"]
    "review-reject"     = ["idp", "migration", "worker"]
    "work-restart"      = ["worker"]
    "passenger-stat"    = ["idp", "worker"]
    "passenger-restart" = ["idp", "worker"]
  }
}

variable "iam_account_alias" {
  description = "Account alias in AWS."
}

variable "region" {
  default = "us-west-2"
}

variable "fisma_tag" {
  default = "Q-LG"
}

variable "state_lock_table" {
  description = "Name of the DynamoDB table to use for state locking with the S3 state backend, e.g. 'terraform-locks'"
  default     = "terraform_locks"
}

variable "manage_state_bucket" {
  description = <<EOM
Whether to manage the TF remote state bucket and lock table.
Set this to false if you want to skip this for bootstrapping.
EOM
  type        = bool
  default     = true
}

variable "master_account_id" {
  default     = "340731855345"
  description = "AWS Account ID for master account"
}

variable "tooling_account_id" {
  default     = "034795980528"
  description = "AWS Account ID for tooling account"
}

variable "toolingprod_account_id" {
  default     = "217680906704"
  description = "AWS Account ID for tooling prod account"
}

variable "auditor_accounts" {
  description = "Map of non-Login.gov AWS accounts we allow Security Auditor access to"
  # Unlike our master account, these are accounts we do not control!
  type = map(string)
  default = {
    master        = "340731855345" # Include master for testing
    techportfolio = "133032889584" # TTS Tech Portfolio
  }
}

variable "s3_block_all_public_access" {
  description = "Set to true to disable all S3 public access, account wide"
  type        = bool
  default     = true
}

variable "reports_bucket_arn" {
  description = "ARN for the S3 bucket for reports."
  type        = string
  default     = ""
}

variable "account_roles_map" {
  description = "Map of roles that are enabled/disabled in current account."
  type        = map(any)
  default     = {}
}

variable "cloudtrail_event_selectors" {
  description = "Map of event_selectors used by default CloudTrail."
  type        = list(any)
  default     = []
}

variable "slack_username" {
  description = "Default username for SNS-to-Slack alert to display in Slack channels."
  type        = string
  default     = "SNSToSlack Notifier"
}

variable "slack_icon" {
  description = "Default icon for SNS-to-Slack alert to display in Slack channels."
  type        = string
  default     = ":login-dot-gov:"
}

variable "legacy_bucket_list" {
  description = <<EOM
List of ad-hoc / legacy S3 buckets created outside of Terraform / unmanaged
by the identity-devops repo, now configured with Intelligent Tiering storage.
EOM
  type        = list(string)
  default     = []
}

variable "opsgenie_key_ready" {
  description = <<EOM
Whether or not the OpsGenie API key is present in this account's secrets
bucket. Defaults to TRUE; set to FALSE only when building from scratch,
as the key will need to be uploaded into the bucket once it has been created.
EOM
  type        = bool
  default     = true
}

variable "splunk_oncall_routing_keys" {
  description = <<EOM
A map of Splunk OnCall routing keys (key) to description entries.  A SNS
topic in supported regions will be created for each routing key.

The splunk_oncall_endpoint file must exist in S3 for the account before
creating these topics.  Set to {} if creating a new account without the
file present.
EOM
  type        = map(string)
  default = {
    "login-platform"    = "Platform oncall alerts",
    "login-application" = "General product engineer/appdev alerts"
  }
}

variable "tf_slack_channel" {
  description = "Slack channel where Terraform change notifications should be sent."
  type        = string
  default     = "#login-change"
}

variable "smtp_user_ready" {
  description = <<EOM
Whether or not the SMTP user is present in this account, and the SMTP username
and password are in this account's secrets bucket. Defaults to FALSE; set to
TRUE after the user has been created and the secrets have been uploaded to the
bucket.
EOM
  type        = bool
  default     = false
}

variable "config_access_key_rotation_name" {
  description = "Name of the Config access key rotation, used to name other resources"
  type        = string
  default     = "cfg-access-key-rotation"
}

variable "config_access_key_rotation_frequency" {
  type        = string
  description = "The frequency that you want AWS Config to run evaluations for the rule."
  default     = "TwentyFour_Hours"
}

variable "config_access_key_rotation_max_key_age" {
  type        = string
  description = "Maximum number of days without rotation. Default 90."
  default     = 90
}

variable "config_access_key_rotation_code" {
  type        = string
  description = "Path of the compressed lambda source code."
  default     = "src/config-access-key-rotation.zip"
}

variable "slack_events_sns_topic" {
  type        = string
  description = "Name of the SNS topic for slack."
  default     = "slack-otherevents"
}

variable "phd_alerted_services" {
  description = "List Person Health event service types that should result in a notification"
  type        = list(string)

  # Where did this list come from?  These are the services we use from the full list
  # of services here:
  #   aws health describe-event-types | jq -r '.eventTypes[] | .service' | sort | uniq
  default = [
    "ACCOUNT",
    "ACM",
    "APIGATEWAY",
    "APPMESH",
    "ATHENA",
    "AUTOSCALING",
    "BILLING",
    "CLOUDFRONT",
    "CLOUDTRAIL",
    "CLOUDWATCHSYNTHETICS",
    "CLOUDWATCH",
    "CONFIG",
    "DETECTIVE",
    "DMS",
    "DYNAMODB",
    "EBS",
    "EC2",
    "ECR",
    "ECR_PUBLIC",
    "EKS",
    "ELASTICACHE",
    "ELASTICLOADBALANCING",
    "EVENTS",
    "GLUE",
    "GUARDDUTY",
    "HEALTH",
    "IAM",
    "INSPECTOR2",
    "INSPECTOR",
    "INTERNETCONNECTIVITY",
    "KINESISSTREAMS",
    "KINESIS",
    "KMS",
    "LAMBDA",
    "MACIE",
    "MANAGEMENTCONSOLE",
    "MARKETPLACE",
    "MULTIPLE_SERVICES",
    "NATGATEWAY",
    "NETWORKFIREWALL",
    "NOTIFICATIONS",
    "ORGANIZATIONS",
    "RDS",
    "REACHABILITY_ANALYZER",
    "RESOURCE_GROUPS",
    "ROUTE53PRIVATEDNS",
    "ROUTE53RESOLVER",
    "ROUTE53",
    "RUM",
    "S3",
    "SECRETSMANAGER",
    "SECURITYHUB",
    "SECURITY",
    "SERVICEDISCOVERY",
    "SERVICEQUOTAS",
    "SES",
    "SHIELD",
    "SIGNIN",
    "SMS",
    "SNS",
    "SQS",
    "SSM",
    "SSO",
    "SUPPORTCENTER",
    "TAG",
    "TRANSIT_GATEWAY",
    "VPCE_PRIVATELINK",
    "VPC",
    "WAF",
    "XRAY",
  ]
}

variable "dnssec_zone_exists" {
  type        = bool
  description = <<EOM
Whether or not DNSSEC is enabled for the primary hosted zone. If it does, get
the DNSSecDisablePrevent IAM policy and attach it to all roles.
EOM
  default     = false
}

variable "externalId" {
  type        = string
  description = "sts assume role, externalId for Prisma Cloud role"
  default     = "3b5fe41c-f3f1-4b36-84a5-5d2a665c87c9"
}

variable "accountNumberPrisma" {
  type        = string
  description = "Commericial Prisma AWS account id"
  default     = "188619942792"
}

variable "ssm_access_map" {
  type        = map(list(map(list(string))))
  description = "Map of SSM docs available to specific roles"
  default     = {}
}

variable "refresher_schedule" {
  description = "Frequency of TA refresher lambda execution"
  default     = "cron(0 14 * * ? *)"
}

variable "monitor_schedule" {
  description = "Frequency of TA monitor lambda execution"
  default     = "cron(10 14 * * ? *)"
}

variable "config_password_rotation_name" {
  description = "Name of the Config Password rotation, used to name other resources"
  type        = string
  default     = "cfg-password-rotation"
}

variable "password_rotation_frequency" {
  type        = string
  description = "The frequency that you want AWS Config to run evaluations for the rule."
  default     = "TwentyFour_Hours"
}

variable "password_rotation_max_key_age" {
  type        = string
  description = "Maximum number of days without rotation. Default 90."
  default     = 90
}

variable "config_password_rotation_code" {
  type        = string
  description = "Path of the compressed lambda source code."
  default     = "lambda/config-password-rotation.zip"
}

variable "PrismaCloudRoleName" {
  type        = string
  description = "IAM role name to be assumed by PrismaCloud followed by session name in the format:/role-name/role-session-name"
  default     = "/PrismaCloudRole/redlock"
}

variable "NewRelicARNRoleName" {
  type        = string
  description = "IAM role name to be assumed by NewRelic Integrations followed by session name in the format:/role-name/role-session-name"
  default     = "/NewRelicInfrastructure-Integrations/newrelic-infrastructure"
}

variable "period" {
  type        = number
  default     = 60
  description = "The period in seconds over which the specified statistic is applied."
}

variable "evaluation_periods" {
  type        = number
  description = "The number of periods over which data is compared to the specified threshold."
  default     = 15
}

variable "threshold" {
  type        = number
  default     = 1
  description = "The value against which the specified statistic is compared. "
}

variable "datapoints_to_alarm" {
  type        = number
  default     = 12
  description = "The number of datapoints that must be breaching to trigger the alarm."
}

variable "soc_logs_enabled" {
  type        = bool
  default     = true
  description = <<EOM
Enables creation of log_ship_to_soc module, allowing shipping of CloudWatch logs to
SOC core account. Must be set to false for new accounts until the SOCaaS team has
approved and confirmed access to the destination CloudWatch log group. More info:
https://github.com/18F/identity-devops/wiki/Runbook:-GSA-SOC-as-a-Service-(SOCaaS)#cloudwatch-shipping-important-note
EOM
}

variable "ses_email_limit" {
  type        = number
  default     = 21600
  description = "This is the limit of emails per 6 hour period. Default is 1 per second, only prod should override."
}

variable "permission_boundary_policy_name" {
  type        = string
  description = <<EOM
The name of the permission boundary IAM policy (created in terraform/guardrail) to be attached to assumable roles. 
Will not create permission boundary if left blank. 
EOM
  default     = ""
}

variable "guardduty_log_group_id" {
  type        = string
  description = "Name of the CloudWatch Log Group to log GuardDuty findings."
  default     = "/aws/events/gdfindings"
}

variable "guardduty_finding_freq" {
  type        = string
  description = "Frequency of notifications for GuardDuty findings."
  default     = "SIX_HOURS"
}

variable "guardduty_s3_enable" {
  type        = bool
  description = "Whether or not to enable S3 protection in GuardDuty"
  default     = false
}

variable "guardduty_k8s_audit_enable" {
  type        = bool
  description = <<EOM
Whether or not to enable Kubernetes audit logs as a data source
for Kubernetes protection (via GuardDuty).
EOM
  default     = false
}

variable "guardduty_ec2_ebs_enable" {
  type        = bool
  description = <<EOM
Whether or not to enable Malware Protection (via scanning EBS volumes)
as a data source for EC2 instances (via GuardDuty).
EOM
  default     = false
}

variable "guardduty_usw2_soc_enabled" {
  type        = bool
  description = <<EOM
Whether or not to create the CloudWatch Subscription Filter that sends
GuardDuty logs to SOC. Must be set to 'false' until the SOCaaS team
confirms the elp-guardduty-lg destination for us-west-2.
EOM
  default     = false
}

variable "guardduty_use1_soc_enabled" {
  type        = bool
  description = <<EOM
Whether or not to create the CloudWatch Subscription Filter that sends
GuardDuty logs to SOC. Must be set to 'false' until the SOCaaS team
confirms the elp-guardduty-lg destination for us-east-1.
EOM
  default     = false
}
