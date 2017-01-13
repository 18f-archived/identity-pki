provider "aws" {
  region = "${var.region}"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    principals = {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/demo_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/int_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/pt_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/astone_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/qa_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tf_elk_iam_role"
      ]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::login-gov-cloudtrail-${data.aws_caller_identity.current.account_id}"
    ]
  }
  statement {
    principals = {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/demo_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/int_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/pt_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/astone_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/qa_elk_iam_role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tf_elk_iam_role"
      ]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::login-gov-cloudtrail-${data.aws_caller_identity.current.account_id}/*"
    ]
  }

  statement {
    principals = {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [
      "arn:aws:s3:::login-gov-cloudtrail-${data.aws_caller_identity.current.account_id}"
    ]
  }
  statement {
    principals = {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::login-gov-cloudtrail-${data.aws_caller_identity.current.account_id}/*"
    ]
    condition {
      test = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "login-gov-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  policy = "${data.aws_iam_policy_document.cloudtrail.json}"

  lifecycle_rule {
    id = "logexpire"
    prefix = ""
    enabled = true

    expiration {
      days = 30
    }
  }
}

resource "aws_cloudtrail" "cloudtrail" {
  name = "login-gov-cloudtrail"
  s3_bucket_name = "${aws_s3_bucket.cloudtrail.id}"
  include_global_service_events = false
}

