# Role that represents the minimum permissions every instance should have for
# service discovery and citadel to work:
#
# - Secrets bucket access for citadel.
# - Self signed certs bucket access for service discovery.
# - Describe instances permission for service discovery.
#
# Add this as the role for an aws_iam_instance_profile.
#
# Note that terraform < 0.9 has a "roles" attribute on aws_iam_instance_profile
# even though there is a 1:1 mapping between iam_instance_profiles and
# iam_roles, so if your instance needs other permissions you can't use this.
resource "aws_iam_role" "base-permissions" {
  name               = "${var.env_name}-base-permissions"
  description        = "Enables the minimum permissions every instance should have for service discovery and citadel to work."
  assume_role_policy = data.aws_iam_policy_document.assume_role_from_vpc.json
}

# Role policy that associates it with the secrets_role_policy
resource "aws_iam_role_policy" "base-permissions-secrets" {
  name   = "${var.env_name}-base-permissions-secrets"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.secrets_role_policy.json
}

# Role policy that associates it with the certificates_role_policy
resource "aws_iam_role_policy" "base-permissions-certificates" {
  name   = "${var.env_name}-base-permissions-certificates"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.certificates_role_policy.json
}

# Role policy that associates it with the describe_instances_role_policy
resource "aws_iam_role_policy" "base-permissions-describe_instances" {
  name   = "${var.env_name}-base-permissions-describe_instances"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.describe_instances_role_policy.json
}

resource "aws_iam_role_policy" "base-permissions-cloudwatch-logs" {
  name   = "${var.env_name}-base-permissions-cloudwatch-logs"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.cloudwatch-logs.json
}

resource "aws_iam_role_policy" "base-permissions-cloudwatch-agent" {
  name   = "${var.env_name}-base-permissions-cloudwatch-agent"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.cloudwatch-agent.json
}

# allow all instances to send a dying SNS notice
resource "aws_iam_role_policy" "base-permissions-sns-publish-alerts" {
  name   = "${var.env_name}-base-permissions-sns-publish-alerts"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.sns-publish-alerts-policy.json
}

# all all instances to upload and download from transfer utility

resource "aws_iam_role_policy" "base-permissions-transfer-utility" {
  name   = "${var.env_name}-base-permissions-transfer-utility"
  role   = aws_iam_role.base-permissions.id
  policy = data.aws_iam_policy_document.transfer_utility_policy.json
}

resource "aws_iam_role" "flow_role" {
  name               = "${var.env_name}_flow_role"
  description        = "Allows VPC Flow Logs to publish logs to AWS CloudWatch."
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "flow_policy" {
  name   = "${var.env_name}_flow_policy"
  role   = aws_iam_role.flow_role.id
  policy = data.aws_iam_policy_document.flow_policy.json
}

data "aws_iam_policy_document" "flow_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.flow_log_group.arn,
      "${aws_cloudwatch_log_group.flow_log_group.arn}:*"
    ]
  }
}
