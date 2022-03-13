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