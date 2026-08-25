data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "gateway" {
  name = "${var.project_name}-mcp-gateway-role"

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
          "aws:SourceArn" = "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:*"
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
