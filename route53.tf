data "aws_route53_zone" "thetwoj" {
  name         = "thetwoj.com"
  private_zone = false
}

resource "aws_route53_record" "thetwoj_validation" {
  for_each = {
    for dvo in aws_acm_certificate.thetwoj_ssl_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.thetwoj.zone_id
}

resource "aws_route53_record" "thetwoj" {
  zone_id = data.aws_route53_zone.thetwoj.zone_id
  name    = "thetwoj.com"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.thetwoj_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.thetwoj_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}