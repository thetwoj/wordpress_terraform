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