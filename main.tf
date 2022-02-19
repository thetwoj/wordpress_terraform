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
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "personal"
  region  = "us-east-2"
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
    App = "Wordpress"
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
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

resource "aws_eip" "wordpress_eip" {
  vpc = true
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

resource "aws_eip_association" "wordpress_eip_assoc" {
  instance_id   = aws_instance.wordpress_ec2.id
  allocation_id = aws_eip.wordpress_eip.id
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
  tags = {
    App    = "Wordpress"
    Metric = "CPU"
  }
}