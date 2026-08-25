# ============================================================================
# Demo Stage 1 - bare harness. See README.md for the full stage-by-stage
# walkthrough; each stage is its own independently-applicable folder rather
# than a commented-out block in a shared file, so stages can be pre-applied
# side by side ahead of a live presentation.
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

  # No memory, no tools - the smallest thing that's a working agent.
  memory {
    disabled {}
  }
}
