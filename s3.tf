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