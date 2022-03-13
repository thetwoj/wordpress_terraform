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
    "InstanceId"   = aws_spot_instance_request.wordpress_ec2.spot_instance_id
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
    "InstanceId" = aws_spot_instance_request.wordpress_ec2.spot_instance_id
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