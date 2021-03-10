module "socadmin-assumerole" {
  source = "github.com/18F/identity-terraform//iam_assumerole?ref=main"

  role_name                = "SOCAdministrator"
  enabled                  = lookup(
                                merge(local.role_enabled_defaults,var.account_roles_map),
                                "iam_socadmin_enabled",
                                lookup(local.role_enabled_defaults,"iam_socadmin_enabled")
                              )
  master_assumerole_policy = local.master_assumerole_policy
  custom_policy_arns       = local.custom_policy_arns

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
            "cloudtrail:*",
            "cloudwatch:*",
            "logs:*",
            "config:*",
            "ec2:DescribeRegions",
            "elasticloadbalancing:*",
            "guardduty:*",
            "iam:Get*",
            "iam:List*",
            "iam:Generate*",
            "inspector:*",
            "macie:*",
            "macie2:*",
            "organizations:List*",
            "organizations:Describe*",
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
          ]
          resources = [
            "*"
          ]
        },
      ]
    }
  ]
}
