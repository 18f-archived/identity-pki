resource "aws_vpc_endpoint" "private-s3" {
  vpc_id          = aws_vpc.auto_terraform.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_vpc.auto_terraform.main_route_table_id]

  tags = {
    Name = "auto_terraform_s3"
  }
}

resource "aws_vpc_endpoint" "private-dynamodb" {
  vpc_id          = aws_vpc.auto_terraform.id
  service_name    = "com.amazonaws.${var.region}.dynamodb"
  route_table_ids = [aws_vpc.auto_terraform.main_route_table_id]

  tags = {
    Name = "auto_terraform_dynamodb"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.auto_terraform.id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.auto_terraform.id]
  subnet_ids          = [aws_subnet.auto_terraform_public.id]
  private_dns_enabled = true

  tags = {
    Name = "auto_terraform_ec2"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.auto_terraform.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.auto_terraform.id]
  subnet_ids          = [aws_subnet.auto_terraform_public.id]
  private_dns_enabled = true

  tags = {
    Name = "auto_terraform_logs"
  }
}

data "aws_vpc_endpoint_service" "sts" {
  service      = "sts"
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.auto_terraform.id
  service_name        = data.aws_vpc_endpoint_service.sts.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.auto_terraform.id]
  subnet_ids          = [aws_subnet.auto_terraform_public.id]
  private_dns_enabled = true

  tags = {
    Name = "auto_terraform_sts"
  }
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.auto_terraform.id
  service_name        = "com.amazonaws.${var.region}.sns"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.auto_terraform.id]
  subnet_ids          = [aws_subnet.auto_terraform_public.id]
  private_dns_enabled = true

  tags = {
    Name = "auto_terraform_sns"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.auto_terraform.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.auto_terraform.id]
  subnet_ids          = [aws_subnet.auto_terraform_public.id]
  private_dns_enabled = true

  tags = {
    Name = "auto_terraform_ssm"
  }
}
