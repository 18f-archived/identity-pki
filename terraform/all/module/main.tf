resource "aws_iam_account_alias" "standard_alias" {
  account_alias = var.iam_account_alias
}

data "aws_caller_identity" "current" {}

# allow assuming of roles from login-master
data "aws_iam_policy_document" "master_account_assumerole" {
  statement {
    sid = "AssumeRoleFromMasterAccount"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.master_account_id}:root"
      ]
    }
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values = [
        "true"
      ]
    }
  }
  statement {
    sid = "PassSessionTagFromMasterAccount"
    actions = [
      "sts:TagSession"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.master_account_id}:root"
      ]
    }
  }
}

# used for assuming of AutoTerraform role from tooling
data "aws_iam_policy_document" "autotf_assumerole" {
  statement {
    sid = "AssumeTerraformRoleFromAutotfRole"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.tooling_account_id}:role/auto_terraform"
      ]
    }
  }
}

# get DNSSEC prevent-delete policy if dnssec_zone_exists = true
data "aws_iam_policy" "dnssec_disable_prevent" {
  count = var.dnssec_zone_exists ? 1 : 0

  name = "DNSSecDisablePrevent"
}

locals {
  bucket_name_prefix       = "login-gov"
  secrets_bucket_type      = "secrets"
  cert_secrets_bucket_type = "internal-certs"
}
