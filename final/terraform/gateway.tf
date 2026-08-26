# The search Lambda is owned by 0-util/terraform, looked up via the
# cross-root data source in lambda_data.tf - same pattern as the staged
# 4-mcp-gateway folder. final/ no longer keeps its own copy of the
# DynamoDB/Lambda stack; only 0-util does, applied once and shared.

resource "aws_bedrockagentcore_gateway" "mcp" {
  name            = "${var.project_name}-knowledge-base-mcp"
  role_arn        = aws_iam_role.gateway.arn
  authorizer_type = "AWS_IAM"
  protocol_type   = "MCP"

  protocol_configuration {
    mcp {
      supported_versions = ["2025-03-26"]
    }
  }

  tags = {
    Name   = "${var.project_name}-knowledge-base-mcp"
    Module = "MCPGateway"
  }
}

resource "aws_bedrockagentcore_gateway_target" "search_knowledge_base" {
  name               = "KnowledgeBase"
  gateway_identifier = aws_bedrockagentcore_gateway.mcp.gateway_id
  description        = "Searches the schematical.com blog post knowledge base via DynamoDB vector search."

  target_configuration {
    mcp {
      lambda {
        lambda_arn = data.aws_lambda_function.search.arn

        tool_schema {
          inline_payload {
            name        = "search_knowledge_base"
            description = "Search the schematical.com blog post knowledge base for content relevant to a query."

            input_schema {
              type = "object"

              property {
                name        = "query"
                description = "The search query."
                type        = "string"
                required    = true
              }
            }
          }
        }
      }
    }
  }

  credential_provider_configuration {
    gateway_iam_role {}
  }
}
