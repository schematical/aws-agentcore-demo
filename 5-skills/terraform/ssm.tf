# Published for manual/external use (e.g. testing the raw MCP endpoint with
# an outside client) - the harness in this same folder's main.tf reads the
# Gateway's ARN directly off aws_bedrockagentcore_gateway.mcp, not via SSM,
# since both resources live in this one root.
resource "aws_ssm_parameter" "gateway_arn" {
  name  = "/${var.project_name}/mcp-gateway/arn"
  type  = "String"
  value = aws_bedrockagentcore_gateway.mcp.gateway_arn

  tags = {
    Name   = "${var.project_name}-mcp-gateway-arn"
    Module = "MCPGateway"
  }
}

# Kept alongside gateway_arn - not consumed by the harness's agentcore_gateway
# tool type (which wants the ARN), but useful for manually testing the raw
# MCP endpoint with an external client later.
resource "aws_ssm_parameter" "gateway_url" {
  name  = "/${var.project_name}/mcp-gateway/url"
  type  = "String"
  value = aws_bedrockagentcore_gateway.mcp.gateway_url

  tags = {
    Name   = "${var.project_name}-mcp-gateway-url"
    Module = "MCPGateway"
  }
}
