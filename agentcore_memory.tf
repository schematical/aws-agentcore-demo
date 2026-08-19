resource "aws_bedrockagentcore_memory" "agentcore_memory" {
  name                  = "${replace(var.project_name, "-", "_")}"
  description           = "Memory for ${var.project_name} "
  event_expiry_duration = 30 # Days
}