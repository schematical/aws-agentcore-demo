data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "gateway" {
  name = "${var.project_name}-mcp-gateway-role"

  # SourceArn is scoped to gateway/<name>* per AWS's own documented trust-
  # policy example (a bare account/region wildcard triggered "Gateway
  # service is not authorized to perform AssumeRole on Gateway role" on
  # gateway_target creation): https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway-prerequisites-permissions.html#gateway-service-role-permissions-trust
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AssumeRolePolicy"
      Effect = "Allow"
      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:gateway/${var.project_name}-knowledge-base-mcp*"
        }
      }
    }]
  })

  tags = {
    Name   = "${var.project_name}-mcp-gateway-role"
    Module = "MCPGateway"
  }
}

resource "aws_iam_role_policy" "gateway" {
  name = "MCPGatewayPolicy"
  role = aws_iam_role.gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeSearchLambda"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = data.aws_lambda_function.search.arn
      }
    ]
  })
}
