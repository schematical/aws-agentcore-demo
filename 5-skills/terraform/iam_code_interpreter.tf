# Execution role for the custom Code Interpreter resource in
# code_interpreter.tf. This is deliberately separate from both the Gateway
# role (iam.tf) and the harness's own execution role (iam_harness.tf): AWS
# credentials for code running inside a Code Interpreter sandbox come from
# THIS role via a session-scoped STS AssumeRole that AgentCore's control
# plane performs on the sandbox's behalf - not from the harness's
# execution_role_arn, and not from IMDS or any caller-passthrough mechanism.
# The AWS-managed default sandbox (what this stage used before adding this
# file - a `tool { type = "agentcore_code_interpreter" }` block with no
# `config`) has NO execution role and therefore no AWS credentials at all.
# See https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter-s3-integration.html
resource "aws_iam_role" "code_interpreter" {
  name = "${var.project_name}-code-interpreter-role"

  # No ArnLike/SourceArn condition - AWS's own worked example for this
  # exact role type (code-interpreter-s3-integration.html) uses only
  # SourceAccount, no SourceArn. A previous revision here added an ArnLike
  # `code-interpreter/*` condition "to follow the Gateway role's
  # convention" (unverified assumption, flagged as such at the time) -
  # confirmed wrong by a real apply: "CodeInterpreter role validation
  # failed ... verify that the role exists and its trust policy allows
  # assumption by this service". Removed rather than guessing a different
  # ArnLike shape. See https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter-s3-integration.html
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
    Name   = "${var.project_name}-code-interpreter-role"
    Module = "Skills"
  }
}


resource "aws_iam_role_policy" "code_interpreter" {
  name = "TerraformDiagramS3Policy"
  role = aws_iam_role.code_interpreter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UploadAndPresignDiagrams"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.skills.arn}/*"
      }
    ]
  })
}

# Same IAM trust-policy propagation race as time_sleep.gateway_iam_propagation
# in iam.tf - AWS's own reference module (github.com/aws-ia/terraform-aws-
# agentcore) uses a 30s sleep specifically before Code Interpreter creation.
resource "time_sleep" "code_interpreter_iam_propagation" {
  depends_on      = [aws_iam_role_policy.code_interpreter]
  create_duration = "30s"
}
