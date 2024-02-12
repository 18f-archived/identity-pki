module "socadmin-assumerole" {
  source = "github.com/18F/identity-terraform//iam_assumerole?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../../identity-terraform/iam_assumerole"

  role_name = "SOCAdministrator"
  enabled = lookup(
    merge(local.role_enabled_defaults, var.account_roles_map),
    "iam_socadmin_enabled",
    lookup(local.role_enabled_defaults, "iam_socadmin_enabled")
  )
  master_assumerole_policy        = data.aws_iam_policy_document.master_account_assumerole.json
  permissions_boundary_policy_arn = var.permission_boundary_policy_name != "" ? data.aws_iam_policy.permission_boundary_policy[0].arn : ""
  custom_policy_arns = compact([
    aws_iam_policy.rds_delete_prevent.arn,
    aws_iam_policy.region_restriction.arn,
    var.dnssec_zone_exists ? data.aws_iam_policy.dnssec_disable_prevent[0].arn : "",
    aws_iam_policy.ai_service_restriction.arn,
  ])

  iam_policies = [
    {
      policy_name        = "SOCAdministrator"
      policy_description = "Policy for SOC administrators"
      policy_document = [
        {
          sid    = "SOCAdministrator"
          effect = "Allow"
          actions = [
            "access-analyzer:*",
            "athena:*",
            "cloudtrail:*",
            "cloudwatch:*",
            "config:*",
            "detective:*",
            "ec2:DescribeRegions",
            "elasticloadbalancing:*",
            "glue:*",
            "guardduty:*",
            "iam:Get*",
            "iam:List*",
            "iam:Generate*",
            "inspector:*",
            "logs:*",
            "macie:*",
            "macie2:*",
            "organizations:List*",
            "organizations:Describe*",
            "rds:Describe*",
            "rds:List*",
            "s3:HeadBucket",
            "s3:List*",
            "s3:Get*",
            "securityhub:*",
            "shield:*",
            "ssm:*",
            "sns:*",
            "trustedadvisor:*",
            "waf:*",
            "wafv2:*",
            "waf-regional:*",
            "inspector2:*",
          ]
          resources = [
            "*"
          ]
        },
        {
          sid    = "SOCAdministratorBuckets"
          effect = "Allow"
          actions = [
            "s3:PutObject",
            "s3:AbortMultipartUpload",
            "s3:ListBucket",
            "s3:GetObject",
            "s3:DeleteObject",
          ]

          resources = [
            "arn:aws:s3:::login-gov-athena-queries-*",
            "arn:aws:s3:::login-gov-athena-queries-*/*",
            "arn:aws:s3:::aws-athena-query-results-${data.aws_caller_identity.current.account_id}-${var.region}",
            "arn:aws:s3:::aws-athena-query-results-${data.aws_caller_identity.current.account_id}-${var.region}/*"
          ]
        }
      ]
    }
  ]
}
