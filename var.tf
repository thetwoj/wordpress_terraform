variable "wordpress_instance_type" {
  description = "Instance type for Wordpress EC2 instance"
  type        = string
  default     = "t3a.small"
}

variable "wordpress_ami_regex" {
  description = "Regex used to match the name of the Wordpress AMI"
  type        = string
  default     = "^packer-wordpress-*"
}
