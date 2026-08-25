# Unlike the AgentCore runtime resource (which gets a default CloudWatch log
# group automatically), Gateway resources don't get log/trace destinations
# configured for you - this has to be wired up explicitly. Mirrors the
# delivery-source/destination/delivery pattern used in 4-mcp-gateway/terraform,
# retargeted at this tree's own Gateway resource.

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
  name         = "${aws_bedrockagentcore_gateway.mcp.gateway_id}-application-logs-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_gateway.mcp.gateway_arn
}

resource "aws_cloudwatch_log_delivery_source" "gateway_traces" {
  name         = "${aws_bedrockagentcore_gateway.mcp.gateway_id}-traces-source"
  log_type     = "TRACES"
  resource_arn = aws_bedrockagentcore_gateway.mcp.gateway_arn
}

resource "aws_cloudwatch_log_delivery_destination" "gateway_logs" {
  name                       = "${aws_bedrockagentcore_gateway.mcp.gateway_id}-logs-destination"
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

# XRAY-type destinations need no delivery_destination_configuration block -
# confirmed against the provider docs (only CWL/S3/FH destinations need it).
resource "aws_cloudwatch_log_delivery_destination" "gateway_traces" {
  name                       = "${aws_bedrockagentcore_gateway.mcp.gateway_id}-traces-destination"
  delivery_destination_type = "XRAY"

  tags = {
    Name    = "${var.project_name}-mcp-gateway-traces-destination"
    Purpose = "X-Ray trace delivery destination"
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

resource "aws_cloudwatch_log_delivery" "gateway_traces" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.gateway_traces.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.gateway_traces.arn

  tags = {
    Name    = "${var.project_name}-mcp-gateway-traces-delivery"
    Purpose = "Connect gateway traces source to X-Ray destination"
    Module  = "Observability"
  }
}
