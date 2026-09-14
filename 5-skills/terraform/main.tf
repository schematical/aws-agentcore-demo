
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



  skill {
    s3 {
      uri = "s3://${aws_s3_bucket.skills.bucket}/skills/poem/"
    }
  }

}
