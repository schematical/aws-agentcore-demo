data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_bedrockagentcore_harness" "example" {
  harness_name       = "example_with_tools"
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

  tool {
    type = "inline_function"
    name = "get_weather"

    config {
      inline_function {
        description = "Get the current weather for a location"
        input_schema = jsonencode({
          type = "object"
          properties = {
            location = {
              type        = "string"
              description = "City name"
            }
          }
          required = ["location"]
        })
      }
    }
  }
  tool {
    type = "remote_mcp"
    name = ""
  }

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
      strategies            = ["SEMANTIC", "SUMMARIZATION"]
    }
  }
}