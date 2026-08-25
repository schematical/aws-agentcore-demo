resource "aws_bedrockagentcore_browser" "browser" {
  name        = "${replace(var.project_name, "-", "_")}"
  description = "Browser tool for ${var.project_name}"

  network_configuration {
    network_mode = "PUBLIC"
  }
}