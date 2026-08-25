# ============================================================================
# final/ - the complete, fully-wired end state of this demo. A one-time,
# standalone reference build (own state, self-contained - not cross-
# referencing the staged 0-util/1-bare-harness/2-memory/3-browser-tool/
# 4-mcp-gateway folders) representing where the staged walkthrough is headed.
# Not kept in mechanical sync with the staged folders after this point - see
# README.md.
# ============================================================================

resource "aws_bedrockagentcore_harness" "harness" {
  harness_name       = "${var.project_name}-harness"
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
