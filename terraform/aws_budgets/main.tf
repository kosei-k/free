resource "aws_budgets_budget" "monthly_budget" {
  name         = "monthly-cost-budget"
  budget_type  = "COST"
  limit_amount = "10.0"    # 月の予算をUSDで設定
  limit_unit   = "USD"     # 通過単位をUSDに設定
  time_unit    = "MONTHLY" # 月ごとにコストを追跡

  notification {
    comparison_operator        = "GREATER_THAN"    # 予算を超えた場合に通知
    notification_type          = "ACTUAL"          # 実際のコストに基づいて通知
    threshold                  = 80.0              # 80%を超えた場合にアラート
    threshold_type             = "PERCENTAGE"      # 80%を超えた場合にアラート
    subscriber_email_addresses = [var.alert_email] # 通知を受け取るメールアドレス terraform.tfvarsで設定
  }
}