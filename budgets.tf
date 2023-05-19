resource "aws_budgets_budget" "cost" {
  name              = "cost-monthly"
  budget_type       = "COST"
  limit_amount      = "15"
  limit_unit        = "USD"
  time_period_end   = "2087-06-15_00:00"
  time_period_start = "2021-12-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["thetwoj@example.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["thetwoj@example.com"]
  }
}