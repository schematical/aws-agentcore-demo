# Unlike the AgentCore runtime resource (which gets a default CloudWatch log
# group automatically), Gateway resources don't get log/trace destinations
# configured for you - this has to be wired up explicitly. Mirrors the
# delivery-source/destination/delivery pattern already used for the old
# agent runtime (see archive/1-agent-runtime/terraform/cloudwatch.tf),
# retargeted at the Gateway.
#
# APPLICATION_LOGS only for now - an XRAY-type delivery destination requires
# the AWS account's X-Ray Trace Segment Destination to already be set to
# CloudWatch Logs (Transaction Search), an account-wide setting this repo
# deliberately doesn't flip on its own (see README.md Roadmap). Add the
# TRACES source/destination/delivery back here once that's enabled.

resource "aws_cloudwatch_log_group" "gateway_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/gateway/APPLICATION_LOGS/${aws_bedrockagentcore_gateway.mcp.gateway_id}"
  retention_in_days = 14

  tags = {
    Name    = "${var.project_name}-mcp-gateway-logs"
    Purpose = "Gateway application logs"
    Module  = "Observability"
  }
}

resource "aws_cloudwatch_log_delivery_source" "gateway_logs" {
  name         = "${var.project_name}-application-logs-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_gateway.mcp.gateway_arn
}

resource "aws_cloudwatch_log_delivery_destination" "gateway_logs" {
  name                     = "${var.project_name}-logs-destination"
  delivery_destination_type = "CWL"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.gateway_logs.arn
  }

  tags = {
    Name    = "${var.project_name}-mcp-gateway-logs-destination"
    Purpose = "CloudWatch Logs delivery destination"
    Module  = "Observability"
  }
}

resource "aws_cloudwatch_log_delivery" "gateway_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.gateway_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.gateway_logs.arn

  tags = {
    Name    = "${var.project_name}-mcp-gateway-logs-delivery"
    Purpose = "Connect gateway logs source to CloudWatch destination"
    Module  = "Observability"
  }
}
