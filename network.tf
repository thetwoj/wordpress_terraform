resource "aws_subnet" "us_east_2c_subnet" {
  vpc_id                  = aws_default_vpc.default.id
  availability_zone       = "us-east-2c"
  cidr_block              = "172.31.32.0/20"
  map_public_ip_on_launch = true
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}