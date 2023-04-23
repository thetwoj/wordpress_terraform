resource "aws_secretsmanager_secret" "dd_api_key" {
  name = "DD_API_KEY"
}

resource "aws_secretsmanager_secret" "dd_site" {
  name = "DD_SITE"
}