data "aws_iam_policy_document" "config_access_key_rotation_ssm_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "config_access_key_rotation_lambda_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_access_key_rotation_remediation_role" {
  name               = "${var.config_access_key_rotation_name}-ssm-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.config_access_key_rotation_ssm_policy.json
}

resource "aws_iam_role" "config_access_key_rotation_lambda_role" {
  name               = "${var.config_access_key_rotation_name}-lambda-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.config_access_key_rotation_lambda_policy.json
}

data "aws_iam_policy_document" "config_access_key_rotation_ssm_access" {
  statement {
    sid       = "${local.accesskeyrotation_name_iam}ResourceAccess"
    effect    = "Allow"
    actions   = ["config:ListDiscoveredResources"]
    resources = ["*"]
  }
  statement {
    sid       = "${local.accesskeyrotation_name_iam}SNSAccess"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.config_access_key_rotation_topic.arn] # Changes the sns topic to the existing topic
  }
}

resource "aws_iam_policy" "config_access_key_rotation_ssm_access" {
  name        = "${var.config_access_key_rotation_name}-ssm-policy"
  description = "Policy for ${var.config_access_key_rotation_name}-ssm access"
  policy      = data.aws_iam_policy_document.config_access_key_rotation_ssm_access.json
}

resource "aws_iam_role_policy_attachment" "config_access_key_rotation_remediation" {
  role       = aws_iam_role.config_access_key_rotation_remediation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy_attachment" "config_access_key_rotation_ssm_access" {
  role       = aws_iam_role.config_access_key_rotation_remediation_role.name
  policy_arn = aws_iam_policy.config_access_key_rotation_ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "config_access_key_rotation_lambda" {
  role       = aws_iam_role.config_access_key_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}