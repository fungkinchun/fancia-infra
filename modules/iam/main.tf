resource "aws_iam_user" "account" {
  name = var.account_name
}

resource "aws_iam_user_policy_attachment" "account_policy_attachment" {
  user       = aws_iam_user.account.name
  policy_arn = var.account_policy_arn
}

resource "aws_iam_access_key" "account_access_key" {
  user = aws_iam_user.account.name
}

output "account_arn" {
  value = aws_iam_user.account.arn
}

output "account_access_key_id" {
  value     = aws_iam_access_key.account_access_key.id
  sensitive = true
}

output "account_secret_access_key" {
  value     = aws_iam_access_key.account_access_key.secret
  sensitive = true
}
