resource "aws_cloudwatch_log_group" "api-log-group" {
  name              = "/ecs/canary"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "api-log-stream" {
  name           = "canary-log-stream"
  log_group_name = aws_cloudwatch_log_group.api-log-group.name
}

resource "aws_cloudwatch_log_group" "nginx-log-group" {
  name              = "/ecs/nginx"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "nginx-log-stream" {
  name           = "nginx-log-stream"
  log_group_name = aws_cloudwatch_log_group.nginx-log-group.name
}

resource "aws_cloudwatch_log_group" "migrate-log-group" {
  name              = "/ecs/migrate"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "migrate-log-stream" {
  name           = "migrate-log-stream"
  log_group_name = aws_cloudwatch_log_group.nginx-log-group.name
}