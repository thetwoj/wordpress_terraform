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