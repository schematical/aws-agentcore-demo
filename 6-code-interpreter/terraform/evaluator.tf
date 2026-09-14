

resource "aws_bedrockagentcore_evaluator" "terraform_diagram_skill" {
  evaluator_name = "terraform_diagram_skill_eval"
  description    = "Scores whether the terraform-diagram skill correctly diagrammed a Terraform directory, rendered a PNG, and uploaded it to S3"
  level          = "TRACE"

  evaluator_config {
    llm_as_a_judge {
      instructions = <<-EOT
        Given the {context} (the tool calls and code interpreter output from
        an agent session) and the {assistant_turn} (the agent's final
        response to the user), judge whether the terraform-diagram skill was
        executed correctly:
        - PASS: the agent parsed the requested Terraform directory, produced
          a Mermaid diagram reflecting its resources/data sources/modules,
          rendered it to a PNG via the code interpreter, uploaded the PNG to
          S3, and returned a working presigned URL to the user.
        - PARTIAL: the skill was invoked and something was produced, but with
          a real defect - e.g. the diagram omits resources, the code
          interpreter errored and was not recovered from, or a URL was
          returned without evidence the upload actually happened.
        - FAIL: the skill was not used when it should have been, no diagram
          or upload occurred, or the agent fabricated a diagram/URL without
          actually running the code interpreter.
      EOT

      rating_scale {
        categorical {
          label      = "PASS"
          definition = "Correct diagram rendered, uploaded to S3, working presigned URL returned."
        }
        categorical {
          label      = "PARTIAL"
          definition = "Skill attempted but with a real defect (incomplete diagram, unrecovered error, unverified URL)."
        }
        categorical {
          label      = "FAIL"
          definition = "Skill not used, no diagram produced, or a fabricated result."
        }
      }

      model_config {
        bedrock_evaluator_model_config {
          model_id = "us.amazon.nova-2-lite-v1:0"

          inference_config {
            max_tokens  = 1024
            temperature = 0
            top_p       = 1
          }
        }
      }
    }
  }
}
