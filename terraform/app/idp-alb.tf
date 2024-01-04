resource "aws_alb" "idp" {
  name = "${var.name}-idp-alb-${var.env_name}"
  # TODO remove aws_security_group.web.id once new SG is in place
  security_groups = [aws_security_group.idp-alb.id]
  subnets         = [for subnet in aws_subnet.public-ingress : subnet.id]

  enable_tls_version_and_cipher_suite_headers = var.enable_tls_and_cipher_headers

  access_logs {
    bucket  = "login-gov.elb-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
    prefix  = "${var.env_name}/idp"
    enabled = true
  }

  enable_deletion_protection = var.enable_deletion_protection == 1 ? true : false
}

locals {
  # In prod, the TLS cert has only "secure.origin.<domain>"
  # In other environments, the TLS cert has "idp.origin.<env>.<domain>" and "<env>.<domain>"
  # DNS name for the alb for the idp instances
  idp_origin_name = var.env_name == "prod" ? "secure.origin.${var.root_domain}" : "idp.origin.${var.env_name}.${var.root_domain}"
  # DNS name for the cloudfront distribution now infront of the idp instances
  idp_domain_name = var.env_name == "prod" ? "secure.${var.root_domain}" : "idp.${var.env_name}.${var.root_domain}"
  # SAN for cloudfront dns name to allow for quicker removal of CDN
  idp_subject_alt_names = var.env_name == "prod" ? ["secure.${var.root_domain}"] : ["idp.${var.env_name}.${var.root_domain}"]
  idp_cdn_root          = var.env_name == "prod" ? "" : "${var.env_name}.${var.root_domain}"

  host_header_enabled = []
  http_header_enabled = ["enabled"]
}

# Create a TLS certificate with ACM
module "acm-cert-idp" {
  source = "github.com/18F/identity-terraform//acm_certificate?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/acm_certificate"
  domain_name               = local.idp_origin_name
  subject_alternative_names = local.idp_subject_alt_names
  validation_zone_id        = var.route53_id
}

resource "aws_alb_listener" "idp" {
  count             = var.alb_http_port_80_enabled
  load_balancer_arn = aws_alb.idp.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.idp.id
    type             = "forward"
  }
}

# SSL Listener for ALB, swapped default to redirect for use with Cloudfront
resource "aws_alb_listener" "idp-ssl" {
  depends_on = [module.acm-cert-idp.finished_id] # don't use cert until valid

  certificate_arn   = module.acm-cert-idp.cert_arn
  load_balancer_arn = aws_alb.idp.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04"
  default_action {
    type = "redirect"
    redirect {
      host        = local.idp_domain_name
      path        = "/#{path}"
      port        = "#{port}"
      protocol    = "#{protocol}"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "idp_ssl_maintenance" {
  count        = var.enable_cloudfront_maintenance_page ? 1 : 0
  listener_arn = aws_alb_listener.idp-ssl.arn
  priority     = 99

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Temporarily Down for Maintenance"
      status_code  = "503"
    }
  }

  condition {
    dynamic "http_header" {
      for_each = local.http_header_enabled
      content {
        http_header_name = local.cloudfront_security_header.name
        values           = local.cloudfront_security_header.value
      }
    }
  }
}

# Either allows traffic to IDP based on new Cloudfront header if Cloudfront is
# enabled. Otherwise it allows traffic to idp servers based on hostname if
# Cloudfront is disabled to prevent a collision between two aws_lb_listner_rule
# resources swapping their priority from 0 <-> 100
resource "aws_lb_listener_rule" "idp_ssl" {
  listener_arn = aws_alb_listener.idp-ssl.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.idp-ssl.arn
  }

  condition {
    # Conditionally populated if Cloudfront is disabled
    dynamic "host_header" {
      for_each = local.host_header_enabled
      content {
        values = [local.idp_domain_name]
      }
    }
    # Conditionally populated if Cloudfront is enabled
    dynamic "http_header" {
      for_each = local.http_header_enabled
      content {
        http_header_name = local.cloudfront_security_header.name
        values           = local.cloudfront_security_header.value
      }
    }
  }
}

resource "aws_alb_target_group" "idp" {
  depends_on = [aws_alb.idp]

  health_check {
    matcher = "301"
  }

  # TODO: rename to "...-idp-http"
  name     = "${var.env_name}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.network_uw2.vpc_id

  deregistration_delay          = 120
  load_balancing_algorithm_type = var.use_lor_algorithm ? "least_outstanding_requests" : "round_robin"
}

resource "aws_alb_target_group" "idp-ssl" {
  depends_on = [aws_alb.idp]

  health_check {
    matcher             = "200"
    protocol            = "HTTPS"
    path                = var.idp_health_uri
    interval            = 10
    timeout             = 5
    healthy_threshold   = 9 # up for 90 seconds
    unhealthy_threshold = 2 # down for 20 seconds
  }

  stickiness {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 1200
  }

  # TODO: rename to "...-idp-ssl"
  name     = "${var.env_name}-ssl-target-group"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.network_uw2.vpc_id

  deregistration_delay          = 120
  load_balancing_algorithm_type = var.use_lor_algorithm ? "least_outstanding_requests" : "round_robin"

  tags = {
    prefix      = var.env_name
    health_role = "idp"
  }
}

# Creates idp.origin or secure.origin domain name
resource "aws_route53_record" "origin_alb_idp" {
  depends_on = [aws_cloudfront_distribution.idp_static_cdn]
  name       = local.idp_origin_name
  records    = [aws_alb.idp.dns_name]
  ttl        = "300"
  type       = "CNAME"
  zone_id    = var.route53_id
}

