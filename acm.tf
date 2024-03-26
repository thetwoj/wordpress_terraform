resource "aws_acm_certificate" "thetwoj_ssl_cert" {
  domain_name       = "thetwoj.com"
  validation_method = "DNS"
  provider          = aws.virginia

  tags = {
    App = "Wordpress"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "thetwoj" {
  certificate_arn = aws_acm_certificate.thetwoj_ssl_cert.arn
  # validation_record_fqdns = [for record in aws_route53_record.thetwoj_validation : record.fqdn]
  provider = aws.virginia
}
