# ============================================================================
# Demo Stage 5 - Skills. Builds on Stage 4 (4-mcp-gateway) by adding the
# agentcore_code_interpreter tool and the terraform-diagram skill: it parses
# a given directory of .tf files (via python-hcl2), renders the result to a
# PNG with the mermaidx package, uploads it to the S3 bucket in s3.tf, and
# returns a presigned URL. This skill is authored by us, not fetched from a
# third party - its content lives directly in this repo
# (../skills/terraform-diagram/) and is committed as-is.
#
# The skill is registered on the harness via an S3 source
# (skill_registration.tf), not the native `skill` block below - the
# hashicorp/aws provider's `skill` schema only supports the `path` source
# type (files already on the harness's own filesystem, which needs a
# container-image bake or session-start command to actually get there -
# neither set up). AgentCore's `s3` source, by contrast, is fetched by
# AgentCore itself with no extra plumbing - see README.md's Roadmap section
# for the full reasoning and s3.tf for the file uploads.
#
# The code_interpreter tool points at a custom Code Interpreter resource
# (code_interpreter.tf) rather than AWS's default managed sandbox, since the
# PNG-upload step needs real S3 credentials - see that file and
# iam_code_interpreter.tf.
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



  tool {
    type = "agentcore_code_interpreter"
    name = "code_interpreter"

    config {
      agentcore_code_interpreter {
        code_interpreter_arn = aws_bedrockagentcore_code_interpreter.diagram_renderer.code_interpreter_arn
      }
    }
  }

  skill {
    s3 {
      uri = "s3://${aws_s3_bucket.diagrams.bucket}/skills/terraform-diagram/"
    }
  }

}
