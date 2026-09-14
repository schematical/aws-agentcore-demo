
locals {
  code_interpreter_name = "${replace(var.project_name, "-", "_")}_diagram_renderer"
}

resource "aws_bedrockagentcore_code_interpreter" "diagram_renderer" {
  # Waits on the execution role's trust-policy propagation delay - see
  # time_sleep.code_interpreter_iam_propagation in iam_code_interpreter.tf.
  depends_on = [time_sleep.code_interpreter_iam_propagation]

  name               = local.code_interpreter_name
  execution_role_arn = aws_iam_role.code_interpreter.arn

  network_configuration {
    network_mode = "PUBLIC"
  }

  tags = {
    Name   = "${var.project_name}-diagram-renderer"
    Module = "Skills"
  }
}
