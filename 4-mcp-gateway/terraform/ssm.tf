
resource "aws_ssm_parameter" "gateway_arn" {
  name  = "/${var.project_name}/mcp-gateway/arn"
  type  = "String"
  value = aws_bedrockagentcore_gateway.mcp.gateway_arn

  tags = {
    Name   = "${var.project_name}-mcp-gateway-arn"
    Module = "MCPGateway"
  }
}


resource "aws_ssm_parameter" "gateway_url" {
  name  = "/${var.project_name}/mcp-gateway/url"
  type  = "String"
  value = aws_bedrockagentcore_gateway.mcp.gateway_url

  tags = {
    Name   = "${var.project_name}-mcp-gateway-url"
    Module = "MCPGateway"
  }
}
