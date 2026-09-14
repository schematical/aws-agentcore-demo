data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "gateway" {
  name = "${var.project_name}-mcp-gateway-role"

  # No ArnLike/SourceArn condition, per AWS's own documented caveat:
  # "you won't know the gateway ARN before you create it... you can omit
  # the Condition field when you first create the service role"
  # (https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway-prerequisites-permissions.html#gateway-service-role-permissions-trust).
  # A previous revision scoped SourceArn to gateway/<name>* to fix "Gateway
  # service is not authorized to perform AssumeRole on Gateway role" on
  # gateway_target creation - that recurred anyway (IAM trust-policy
  # propagation delay, not a policy-shape problem: the role's trust policy
  # takes a few seconds to become visible to the AssumeRole caller after
  # creation). AWS's own reference module (github.com/aws-ia/terraform-aws-
  # agentcore) uses this same bare SourceAccount-only condition plus an
  # explicit time_sleep before gateway_target creation - see that
  # resource's depends_on in gateway.tf.
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

# IAM trust-policy changes take a few seconds to propagate before Bedrock
# AgentCore can reliably assume the role - gateway_target creation
# immediately after gateway/role creation is exactly the race this closes.
# 15s matches AWS's own reference module's time_sleep for this same step.
resource "time_sleep" "gateway_iam_propagation" {
  depends_on      = [aws_iam_role_policy.gateway]
  create_duration = "15s"
}
