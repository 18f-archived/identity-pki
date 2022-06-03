# Create a TLS certificate with ACM
module "acm-cert-public-reporting-data-cdn" {
  source = "github.com/18F/identity-terraform//acm_certificate?ref=a6261020a94b77b08eedf92a068832f21723f7a2"
  providers = {
    aws = aws.use1
  }

  domain_name        = "public-reporting-data.${var.env_name}.${var.root_domain}"
  validation_zone_id = var.route53_id
}

# The Managed-CORS-S3Origin origin policy passes the Origin, Access-Control-Request-Headers, Access-Control-Request-Method headers to the
# S3 bucket.  We previously used the CloudFront Managed-CachingOptimized caching policy, but this caused issues because the policy does
# not take into account the headers when building the cache key.  This led to situations where if the first request for an object came with
# the header "Origin: https://example.com", S3 would respond with "Access-Control-Allow-Origin: https://example.com".  If later
# requests came from "Origin: https://example2.com", CloudFront would respond with "Access-Control-Allow-Origin: https://example.com" and
# the browser would block the request due to a CORS origin mismatch.
#
# Our solution to this is to have a CloudFront cache policy that includes the headers in the cache key.  This ensures requests with different
# "Origin" headers have separate cache keys.
#
# "Origin" is difficult to search for since it is overloaded in the context of talking about CORS and CloudFront.
# It can refer to either the HTTP header or the CloudFront origin (S3 in this case).
resource "aws_cloudfront_cache_policy" "public_reporting_data_cache_policy" {
  name        = "${var.env_name}-Public-Reporting-Data-Cache-Policy"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "managed_cors_s3origin" {
  name = "Managed-CORS-S3Origin"
}

resource "aws_cloudfront_distribution" "public_reporting_data_cdn" {

  depends_on = [
    aws_s3_bucket.public_reporting_data,
    module.acm-cert-public-reporting-data-cdn.finished_id
  ]

  origin {
    domain_name = aws_s3_bucket.public_reporting_data.bucket_regional_domain_name
    origin_id   = "public-reporting-data-${var.env_name}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cloudfront_oai.cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["public-reporting-data.${var.env_name}.${var.root_domain}"]

  # Throwaway default
  default_root_object = "/index.html"

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET", "OPTIONS"]
    cached_methods   = ["HEAD", "GET", "OPTIONS"]
    target_origin_id = "public-reporting-data-${var.env_name}"

    cache_policy_id          = aws_cloudfront_cache_policy.public_reporting_data_cache_policy.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_cors_s3origin.id

    min_ttl                = 0
    viewer_protocol_policy = "https-only"
    compress               = true
  }

  viewer_certificate {
    acm_certificate_arn      = module.acm-cert-public-reporting-data-cdn.cert_arn
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only"
  }

  # Allow access from anywhere
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Log to ELB log bucket to keep front end AWS logs together.
  # CloudFront logs are batched and may take over 24 hours to appear.
  logging_config {
    bucket          = "login-gov.elb-logs.${data.aws_caller_identity.current.account_id}-${var.region}.s3.amazonaws.com"
    include_cookies = false
    prefix          = "${var.env_name}/cloudfront/"
  }

  # Serve from US/Canada/Europe CloudFront instances
  price_class = "PriceClass_100"
}

resource "aws_route53_record" "public_reporting_data_a" {
  zone_id = var.route53_id
  name    = "public-reporting-data.${var.env_name}.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.public_reporting_data_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.public_reporting_data_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "public_reporting_data_aaaa" {
  zone_id = var.route53_id
  name    = "public-reporting-data.${var.env_name}.${var.root_domain}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.public_reporting_data_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.public_reporting_data_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

module "cloudfront_public_reporting_data_cdn_alarms" {
  count  = var.cdn_public_reporting_data_alarms_enabled
  source = "../modules/cloudfront_cdn_alarms"

  providers = {
    aws = aws.use1
  }
  alarm_actions = local.low_priority_alarm_actions_use1
  dimensions = {
    DistributionId = aws_cloudfront_distribution.public_reporting_data_cdn.id
    Region         = "Global"
  }
  threshold         = 1
  distribution_name = "Public Reporting Data"
  env_name          = var.env_name
}
