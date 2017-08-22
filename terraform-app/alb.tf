resource "aws_alb" "idp" {
  count = "${var.alb_enabled}"
  name = "${var.name}-idp-alb-${var.env_name}"
  security_groups = ["${aws_security_group.web.id}"]
  subnets = ["${aws_subnet.alb1.id}", "${aws_subnet.alb2.id}"]
}

resource "aws_alb_listener" "idp" {
  count = "${var.alb_enabled}"
  depends_on = ["aws_alb.idp"]
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
  certificate_arn = "${aws_iam_server_certificate.idp.arn}"
  load_balancer_arn = "${aws_alb.idp.id}"
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  default_action {
    target_group_arn = "${aws_alb_target_group.idp-ssl.id}"
    type             = "forward"
  }
}

resource "aws_alb_target_group" "idp" {
  count = "${var.alb_enabled}"
  depends_on = ["aws_alb.idp"]

  health_check {
    matcher =  "301"
  }

  name = "${var.env_name}-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_alb_target_group" "idp-ssl" {
  count = "${var.alb_enabled}"
  depends_on = ["aws_alb.idp"]

  health_check {
    # we have HTTP basic auth enabled everywhere except prod and staging
    matcher =  "${var.basic_auth_enabled ? 401 : 200}"
    protocol = "HTTPS"

    interval = 10
    timeout = 5
    healthy_threshold = 9 # up for 90 seconds
    unhealthy_threshold = 2 # down for 20 seconds
  }

  name = "${var.env_name}-ssl-target-group"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${aws_vpc.default.id}"

  # TODO: Do we really want sticky sessions? Not recommended.
  stickiness = {
    type = "lb_cookie"
    enabled = "true"
    cookie_duration = 3600 # 1 hour
  }
}

resource "aws_alb_target_group_attachment" "idp" {
  count = "${var.alb_enabled * var.idp_node_count}"
  depends_on = ["aws_alb.idp"]
  port = 80
  target_group_arn = "${aws_alb_target_group.idp.arn}"
  target_id = "${element(aws_instance.idp1.*.id, count.index)}"
}

resource "aws_alb_target_group_attachment" "idp-ssl" {
  count = "${var.alb_enabled * var.idp_node_count}"
  port = 443
  target_group_arn = "${aws_alb_target_group.idp-ssl.arn}"
  target_id = "${element(aws_instance.idp1.*.id, count.index)}"
}

resource "aws_alb_target_group_attachment" "idp2" {
  count = "${var.alb_enabled * var.idp_node_count}"
  depends_on = ["aws_alb.idp"]
  port = 80
  target_group_arn = "${aws_alb_target_group.idp.arn}"
  target_id = "${element(aws_instance.idp2.*.id, count.index)}"
}

resource "aws_alb_target_group_attachment" "idp2-ssl" {
  count = "${var.alb_enabled * var.idp_node_count}"
  port = 443
  target_group_arn = "${aws_alb_target_group.idp-ssl.arn}"
  target_id = "${element(aws_instance.idp2.*.id, count.index)}"
}

resource "aws_iam_server_certificate" "idp" {
  count = "${var.alb_enabled}"
  certificate_body = "${acme_certificate.idp.certificate_pem}"
  certificate_chain = "${file("${path.cwd}/../certs/lets-encrypt-x3-cross-signed.pem")}"
  name_prefix = "${var.name}-idp-cert-${var.env_name}."
  private_key = "${acme_certificate.idp.private_key_pem}"

  lifecycle {
      create_before_destroy = true
  }
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
  name = "${var.env_name}.login.gov"
  records = ["${aws_alb.idp.dns_name}"]
  ttl = "300"
  type = "CNAME"
  zone_id = "${var.route53_id}"
}

resource "aws_route53_record" "c_alb_idp" {
  count = "${var.env_name == "prod" ? 0 : var.alb_enabled}"
  name = "idp.${var.env_name}.login.gov"
  records = ["${aws_alb.idp.dns_name}"]
  ttl = "300"
  type = "CNAME"
  zone_id = "${var.route53_id}"
}
