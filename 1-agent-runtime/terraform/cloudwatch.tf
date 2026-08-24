resource "aws_cloudwatch_log_group" "agent_runtime_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/${aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id}"
  retention_in_days = 14

  tags = {
    Name    = "${var.project_name}-agent-logs"
    Purpose = "Agent runtime application logs"
    Module  = "Observability"
  }

  depends_on = [aws_bedrockagentcore_agent_runtime.agent]
}
resource "aws_cloudwatch_log_delivery_source" "application_logs" {
  name         = "${aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id}-application-logs-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_arn

  depends_on = [aws_bedrockagentcore_agent_runtime.agent]
}

/*resource "aws_cloudwatch_log_delivery_source" "usage_logs" {
  name         = "${aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id}-usage-logs-source"
  log_type     = "USAGE_LOGS"
  resource_arn = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_arn

  depends_on = [aws_bedrockagentcore_agent_runtime.agent]
}*/
resource "aws_cloudwatch_log_delivery_destination" "logs" {
  name = "${aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id}-logs-destination"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.agent_runtime_logs.arn
  }

  tags = {
    Name    = "${var.project_name}-logs-destination"
    Purpose = "CloudWatch Logs delivery destination"
    Module  = "Observability"
  }

  depends_on = [aws_cloudwatch_log_group.agent_runtime_logs]
}

resource "aws_cloudwatch_log_delivery" "application_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.application_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.logs.arn

  tags = {
    Name    = "${var.project_name}-logs-delivery"
    Purpose = "Connect logs source to CloudWatch destination"
    Module  = "Observability"
  }

  depends_on = [
    aws_cloudwatch_log_delivery_source.application_logs,
    aws_cloudwatch_log_delivery_destination.logs
  ]
}
/*resource "aws_cloudwatch_log_delivery" "usage_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.logs.arn

  tags = {
    Name    = "${var.project_name}-logs-delivery"
    Purpose = "Connect logs source to CloudWatch destination"
    Module  = "Observability"
  }

  depends_on = [
    aws_cloudwatch_log_delivery_source.usage_logs,
    aws_cloudwatch_log_delivery_destination.logs
  ]
}*/