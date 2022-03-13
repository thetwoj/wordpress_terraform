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

resource "aws_spot_instance_request" "wordpress_ec2" {
  ami                    = data.aws_ami.wordpress_ami.id
  instance_type          = var.wordpress_instance_type
  availability_zone      = "us-east-2b"
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.wordpress_instance_profile.name
  hibernation            = false
  user_data              = data.template_file.userdata_script.rendered
  wait_for_fulfillment = true

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
  template = file("./files/userdata_script.tpl")
  vars = {
    ebs_device = "/dev/sdf"
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
  instance_id                    = aws_spot_instance_request.wordpress_ec2.spot_instance_id
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