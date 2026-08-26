# ============================================================================
# final/ - the complete, fully-wired end state of this demo. A one-time
# reference build (own state) representing where the staged walkthrough is
# headed - it owns its own Gateway and harness, but shares 0-util's
# DynamoDB/Lambda stack (via lambda_data.tf) rather than duplicating it, so
# 0-util must be applied first. Not kept in mechanical sync with the staged
# 1-bare-harness/2-memory/3-browser-tool/4-mcp-gateway folders after this
# point - see README.md.
# ============================================================================

# harnessName must satisfy ^[a-zA-Z][a-zA-Z0-9_]{0,39}$ - letters/digits/
# underscore only (no hyphens), max 40 chars. This is the opposite charset
# from the Gateway's name field (hyphens, no underscores), so it can't just
# reuse var.project_name directly even though every other resource in this
# folder does.
locals {
  harness_name = "${replace(var.project_name, "-", "_")}_harness"
}

resource "aws_bedrockagentcore_harness" "harness" {
  harness_name       = local.harness_name
  execution_role_arn = aws_iam_role.agent_execution.arn

  model {
    bedrock_model_config {
      model_id    = "anthropic.claude-sonnet-4-20250514"
      temperature = 0.7
      top_p       = 0.9
    }
  }

  system_prompt {
    text = "You are a coding assistant."
  }

  allowed_tools   = ["*"]
  max_iterations  = 10
  max_tokens      = 4096
  timeout_seconds = 300

  truncation {
    strategy = "sliding_window"

    config {
      sliding_window {
        messages_count = 50
      }
    }
  }

  memory {
    managed_memory_configuration {
      event_expiry_duration = 14
      strategies             = ["SEMANTIC", "SUMMARIZATION"]
    }
  }

  tool {
    type = "agentcore_browser"
    name = "browser"
  }

  tool {
    type = "agentcore_gateway"
    name = "knowledge_base"

    config {
      agentcore_gateway {
        gateway_arn = aws_bedrockagentcore_gateway.mcp.gateway_arn
      }
    }
  }
}
