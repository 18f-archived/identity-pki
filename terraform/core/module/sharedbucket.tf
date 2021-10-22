data "aws_caller_identity" "current" {
}

locals {
  s3_bucket_data = {
    "shared-data" = {},
    "email" = {
      lifecycle_rules = [
        {
          id          = "expireinbound"
          enabled     = true
          prefix      = "/inbound/"
          transitions = []
          # Keep email 90 days then delete
          expiration_days = 90
        }
      ],
      force_destroy = false
    },
    "lambda-functions" = {
      lifecycle_rules = [
        {
          id      = "inactive"
          enabled = true
          prefix  = "/"
          transitions = [
            {
              days          = 180
              storage_class = "STANDARD_IA"
            }
          ]
        }
      ],
      force_destroy = false
    },
    "reports" = {
      lifecycle_rules = [
        {
          id      = "aging"
          enabled = true
          prefix  = "/"
          transitions = [
            {
              days          = 30
              storage_class = "STANDARD_IA"
            }
          ]
        }
      ],
      force_destroy = false
    }
  }
}

module "s3_shared" {
  source = "github.com/18F/identity-terraform//s3_bucket_block?ref=7e11ebe24e3a9cbc34d1413cf4d20b3d71390d5b"
  #source = "../../../../identity-terraform/s3_bucket_block"

  bucket_name_prefix   = "login-gov"
  bucket_data          = local.s3_bucket_data
  log_bucket           = "login-gov.s3-access-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
  inventory_bucket_arn = "arn:aws:s3:::login-gov.s3-inventory.${data.aws_caller_identity.current.account_id}-${var.region}"
}

# Policy for shared-data bucket
resource "aws_s3_bucket_policy" "shared" {
  bucket = module.s3_shared.buckets["shared-data"]
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdministrator"
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["shared-data"]}"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdministrator"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["shared-data"]}/*"
    }
  ]
}
POLICY
}

# Policy covering uploads to the lambda functions bucket
resource "aws_s3_bucket_policy" "lambda-functions" {
  bucket = module.s3_shared.buckets["lambda-functions"]
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCircleCIPuts",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_user.circleci.arn}"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["lambda-functions"]}/circleci/*"
    },
    {
      "Sid": "AllowProdAccountRead",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::555546682965:root"
      },
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["lambda-functions"]}/circleci/*"
    },
    {
      "Sid": "AllowProdAccountBucketRead",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::555546682965:root"
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["lambda-functions"]}"
    }
  ]
}
POLICY
}

# policy allowing SES to upload files to the email bucket under /inbound/*
resource "aws_s3_bucket_policy" "ses-upload" {
  bucket = module.s3_shared.buckets["email"]
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${module.s3_shared.buckets["email"]}/inbound/*",
      "Condition": {
        "StringEquals": {
          "aws:Referer": "${data.aws_caller_identity.current.account_id}"
        }
      }
    }
  ]
}
POLICY
}

# policy allowing download of files from the email bucket under /inbound/*
data "aws_iam_policy_document" "ses-download-policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_user.circleci.arn
      ]
    }
    resources = [
      "arn:aws:s3:::${module.s3_shared.buckets["email"]}/inbound/",
      "arn:aws:s3:::${module.s3_shared.buckets["email"]}/inbound/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "ses-download" {
  bucket = module.s3_shared.buckets["email"]
  policy = data.aws_iam_policy_document.ses-download-policy.json
}

# Create a common bucket for storing ELB/ALB access logs
# The bucket name will be like this:
#   login-gov.elb-logs.<ACCOUNT_ID>-<AWS_REGION>
module "elb-logs" {
  # can't use variable for ref -- see https://github.com/hashicorp/terraform/issues/17994
  source = "github.com/18F/identity-terraform//elb_access_logs_bucket?ref=7e11ebe24e3a9cbc34d1413cf4d20b3d71390d5b"

  region                     = var.region
  bucket_name_prefix         = "login-gov"
  use_prefix_for_permissions = false
  inventory_bucket_arn       = "arn:aws:s3:::login-gov.s3-inventory.${data.aws_caller_identity.current.account_id}-${var.region}"
  lifecycle_days_standard_ia = 60   # 2 months
  lifecycle_days_glacier     = 365  # 1 year
  lifecycle_days_expire      = 2190 # 6 years
}

resource "aws_iam_user" "circleci" {
  name = "bot=circleci"
  path = "/system/"
}

output "elb_log_bucket" {
  value = module.elb-logs.bucket_name
}
