resource "aws_alb" "idp" {
  count = "${var.alb_enabled}"
  name = "${var.name}-idp-alb-${var.env_name}"
  security_groups = ["${aws_security_group.web.id}"]
  subnets = ["${aws_subnet.alb1.id}", "${aws_subnet.alb2.id}"]

  access_logs = {
    bucket = "login-gov.elb-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
    prefix = "${var.env_name}/idp"
    enabled = true
  }

  enable_deletion_protection = "${var.enable_deletion_protection}"
}

locals {
  # In prod, the TLS cert has only "secure.<domain>"
  # In other environments, the TLS cert has "idp.<env>.<domain>" and "<env>.<domain>"
  idp_domain_name = "${var.env_name == "prod" ? "secure.${var.root_domain}" : "idp.${var.env_name}.${var.root_domain}"}"

  # until we upgrade to TF 0.12 we can't use lists as the value outputted by a conditional, so split on space
  idp_subject_alt_names = ["${compact(split(" ", var.env_name == "prod" ? "" : "${var.env_name}.${var.root_domain}"))}"]
}

# Create a TLS certificate with ACM
module "acm-cert-idp" {
  source = "github.com/18F/identity-terraform//acm_certificate?ref=2c43bfd79a8a2377657bc8ed4764c3321c0f8e80"
  enabled = "${var.alb_enabled * var.acm_certs_enabled}"
  domain_name = "${local.idp_domain_name}"
  subject_alternative_names = ["${local.idp_subject_alt_names}"]
  validation_zone_id = "${var.route53_id}"
}

# Fake resource to allow depends_on
# TODO: this can go away in TF 0.12
# https://github.com/hashicorp/terraform/issues/16983
resource "null_resource" "acm-idp-issued" {
  triggers {
    finished = "${module.acm-cert-idp.finished_id}"
  }
}

resource "aws_alb_listener" "idp" {
  count = "${var.alb_enabled * var.alb_http_port_80_enabled}"
  load_balancer_arn = "${aws_alb.idp.id}"
  port = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.idp.id}"
    type = "forward"
  }
}

resource "aws_alb_listener" "idp-ssl" {
  count = "${var.alb_enabled}"
  certificate_arn = "${module.acm-cert-idp.cert_arn}"
  load_balancer_arn = "${aws_alb.idp.id}"
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  default_action {
    target_group_arn = "${aws_alb_target_group.idp-ssl.id}"
    type             = "forward"
  }

  # TODO TF 0.12 syntax:
  # depends_on = ["module.acm-cert-idp.finished_id"] # don't use cert until valid
  depends_on = ["null_resource.acm-idp-issued"] # don't use cert until valid
}

resource "aws_alb_target_group" "idp" {
  count = "${var.alb_enabled}"
  depends_on = ["aws_alb.idp"]

  health_check {
    matcher =  "301"
  }

  # TODO: rename to "...-idp-http"
  name = "${var.env_name}-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.default.id}"

  deregistration_delay = 120
}

resource "aws_alb_target_group" "idp-ssl" {
  count = "${var.alb_enabled}"
  depends_on = ["aws_alb.idp"]

  health_check {
    # we have HTTP basic auth enabled in nonprod envs in the prod AWS account
    matcher =  "${var.basic_auth_enabled ? "401,200" : "200"}"
    protocol = "HTTPS"

    interval = 10
    timeout = 5
    healthy_threshold = 9 # up for 90 seconds
    unhealthy_threshold = 2 # down for 20 seconds
  }

  # TODO: rename to "...-idp-ssl"
  name = "${var.env_name}-ssl-target-group"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${aws_vpc.default.id}"

  deregistration_delay = 120
}

# secure.login.gov is the production-only name for the IDP app
resource "aws_route53_record" "c_alb_production" {
  count = "${var.env_name == "prod" ? var.alb_enabled : 0}"
  name = "secure.login.gov"
  records = ["${aws_alb.idp.dns_name}"]
  ttl = "300"
  type = "CNAME"
  zone_id = "${var.route53_id}"
}

# non-prod envs are currently configured to both idp.<env>.login.gov
# and <env>.login.gov
resource "aws_route53_record" "c_alb" {
  count = "${var.env_name == "prod" ? 0 : var.alb_enabled}"
  name = "${var.env_name}.${var.root_domain}"
  records = ["${aws_alb.idp.dns_name}"]
  ttl = "300"
  type = "CNAME"
  zone_id = "${var.route53_id}"
}

resource "aws_route53_record" "c_alb_idp" {
  count = "${var.env_name == "prod" ? 0 : var.alb_enabled}"
  name = "idp.${var.env_name}.${var.root_domain}"
  records = ["${aws_alb.idp.dns_name}"]
  ttl = "300"
  type = "CNAME"
  zone_id = "${var.route53_id}"
}
