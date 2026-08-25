# ============================================================================
# Demo Stage 2 - memory. Builds on Stage 1 (1-bare-harness) by swapping the
# `disabled {}` memory block for `managed_memory_configuration`. Fully
# self-contained in the harness resource - no separate AWS resource to
# provision. See README.md for the full stage-by-stage walkthrough.
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
}
