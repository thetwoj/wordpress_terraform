terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 0.14.9"

  backend "s3" {
    profile = "personal"
    bucket  = "thetwoj-tfstate"
    key     = "state"
    region  = "us-east-2"
  }
}

provider "aws" {
  profile = "personal"
  region  = "us-east-2"
}

provider "aws" {
  alias   = "virginia"
  profile = "personal"
  region  = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "thetwoj-tfstate"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_ami" "wordpress_ami" {
  owners      = ["self"]
  most_recent = true
  name_regex  = var.wordpress_ami_regex

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:App"
    values = ["Wordpress"]
  }
}

data "aws_route53_zone" "thetwoj" {
  name         = "thetwoj.com"
  private_zone = false
}

resource "aws_instance" "wordpress_ec2" {
  ami                    = data.aws_ami.wordpress_ami.id
  instance_type          = var.wordpress_instance_type
  availability_zone      = "us-east-2b"
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.wordpress_instance_profile.name
  hibernation            = false
  user_data              = data.template_file.userdata_script.rendered

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    tags = {
      App = "Wordpress"
      Use = "Root"
    }
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    App  = "Wordpress"
    Name = "Prod Wordpress"
  }
}

data "template_file" "userdata_script" {
  template = file("userdata_script.tpl")
  vars = {
    ebs_device = "/dev/xvdf"
    ebs_path   = "/ebs"
    efs_id     = aws_efs_file_system.wordpress_content.id
    efs_path   = "/var/www/html/efs"
  }
}

resource "aws_ebs_volume" "wordpress_db_volume" {
  availability_zone = "us-east-2b"
  encrypted         = true
  size              = 22
  type              = "gp3"

  tags = {
    App = "Wordpress"
    Use = "Database"
  }
}

resource "aws_volume_attachment" "wordpress_db_volume_attachment" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.wordpress_db_volume.id
  instance_id                    = aws_instance.wordpress_ec2.id
  stop_instance_before_detaching = true
}

resource "aws_efs_file_system" "wordpress_content" {
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    App = "Wordpress"
    Use = "Content"
  }
}

resource "aws_efs_mount_target" "wordpress_content" {
  file_system_id  = aws_efs_file_system.wordpress_content.id
  security_groups = [aws_security_group.wordpress_efs_sg.id]
  subnet_id       = aws_subnet.us_east_2b_subnet.id
}

resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress-sg"
  description = "Allow HTTP/S and SSH to Wordpress instance"

  ingress {
    description      = "HTTP from CloudFront"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    prefix_list_ids  = ["pl-b6a144df"]  # AWS-maintained prefix list for CloudFront
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    App = "Wordpress"
  }
}

resource "aws_security_group" "wordpress_efs_sg" {
  name        = "wordpress-efs-sg"
  description = "Allow connections to EFS"

  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    App = "Wordpress"
  }
}

resource "aws_subnet" "us_east_2b_subnet" {
  vpc_id                  = aws_default_vpc.default.id
  availability_zone       = "us-east-2b"
  cidr_block              = "172.31.16.0/20"
  map_public_ip_on_launch = true
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_iam_role" "wordpress_iam_role" {
  name        = "EC2WordpressRole"
  description = "Allows EC2 instances to call AWS services on your behalf."

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      }
    ]
  })

  tags = {
    App = "Wordpress"
  }
}

resource "aws_iam_instance_profile" "wordpress_instance_profile" {
  name = "EC2WordpressRole"
  role = aws_iam_role.wordpress_iam_role.name
  tags = {
    App = "Wordpress"
  }
}

resource "aws_iam_role" "wordpress_uptime_monitor_iam_role" {
  name        = "WordpressUptimeLambdaRole"
  description = "Allows lambda to create logs."
  path        = "/service-role/"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    App = "Wordpress"
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.wordpress_uptime_monitor_iam_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_sns_topic" "wordpress_alarm_topic" {
  name = "Wordpress_Alarms_Topic"
  tags = {
    App = "Wordpress"
  }
}

resource "aws_sns_topic_subscription" "wordpress_alarm_emails" {
  topic_arn = aws_sns_topic.wordpress_alarm_topic.arn
  protocol  = "email"
  endpoint  = "thetwoj@gmail.com"
}

data "archive_file" "lambda_wordpress_uptime" {
  type        = "zip"
  output_path = "/tmp/lambda_wordpress_uptime.zip"
  source {
    content  = file("./lambda_wordpress_uptime.py")
    filename = "lambda_wordpress_uptime.py"
  }
}

resource "aws_lambda_function" "wordpress_uptime" {
  function_name    = "WordpressUptime"
  description      = "Wordpress Uptime monitor"
  role             = aws_iam_role.wordpress_uptime_monitor_iam_role.arn
  handler          = "lambda_wordpress_uptime.lambda_handler"
  runtime          = "python3.9"
  timeout          = 5
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_wordpress_uptime.output_path
  source_code_hash = data.archive_file.lambda_wordpress_uptime.output_base64sha256
  depends_on       = [aws_iam_role_policy_attachment.lambda_logs]
}

resource "aws_cloudwatch_event_rule" "wordpress_uptime" {
  name                = "WordpressUptimeRule"
  description         = "EventBridge Rule for WordpressUptime"
  schedule_expression = "rate(5 minutes)"
  tags = {
    App = "Wordpress"
  }
}

resource "aws_cloudwatch_event_target" "wordpress_uptime" {
  arn  = aws_lambda_function.wordpress_uptime.arn
  rule = aws_cloudwatch_event_rule.wordpress_uptime.id
}

resource "aws_cloudwatch_metric_alarm" "wordpress_uptime" {
  alarm_name                = "Wordpress uptime"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "3"
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = "300"
  statistic                 = "Maximum"
  threshold                 = "0"
  datapoints_to_alarm       = 2
  alarm_description         = "Wordpress is down"
  insufficient_data_actions = []
  treat_missing_data        = "breaching"
  dimensions = {
    "FunctionName" = aws_lambda_function.wordpress_uptime.function_name
  }
  alarm_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  ok_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  tags = {
    App    = "Wordpress"
    Metric = "Uptime"
  }
}

resource "aws_cloudwatch_metric_alarm" "wordpress_memory_use" {
  alarm_name                = "Wordpress excessive memory use"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "mem_used_percent"
  namespace                 = "CWAgent"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "85"
  datapoints_to_alarm       = 3
  alarm_description         = "Wordpress using more memory than expected"
  insufficient_data_actions = []
  dimensions = {
    "ImageId"      = data.aws_ami.wordpress_ami.id
    "InstanceId"   = aws_instance.wordpress_ec2.id
    "InstanceType" = var.wordpress_instance_type
  }
  alarm_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  ok_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  tags = {
    App    = "Wordpress"
    Metric = "Memory"
  }
}

resource "aws_cloudwatch_metric_alarm" "wordpress_cpu_util" {
  alarm_name                = "Wordpress CPU util"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "90"
  datapoints_to_alarm       = 3
  alarm_description         = "Excessive CPU util on Wordpress instance"
  insufficient_data_actions = []
  dimensions = {
    "InstanceId" = aws_instance.wordpress_ec2.id
  }
  alarm_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  ok_actions = [
    aws_sns_topic.wordpress_alarm_topic.arn,
  ]
  tags = {
    App    = "Wordpress"
    Metric = "CPU"
  }
}

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

resource "aws_acm_certificate_validation" "thetwoj" {
  certificate_arn         = aws_acm_certificate.thetwoj_ssl_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.thetwoj_validation : record.fqdn]
  provider                = aws.virginia
}

locals {
  thetwoj_ec2_origin_id = "Wordpress EC2"
}

resource "aws_cloudfront_distribution" "thetwoj_distribution" {
  origin {
    domain_name = aws_instance.wordpress_ec2.public_dns
    origin_id   = local.thetwoj_ec2_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Distribution for thetwoj.com"
  aliases         = ["thetwoj.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.thetwoj_ec2_origin_id
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

    viewer_protocol_policy = "redirect-to-https"
    compress = true
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    App = "Wordpress"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.thetwoj_ssl_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
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

