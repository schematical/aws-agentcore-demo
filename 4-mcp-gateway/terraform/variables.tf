variable "project_name" {
  type    = string
  default = "schematical-demo-stage4"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

# Separate from project_name above: this must match 0-util/terraform's own
# project_name (not this folder's) since it's used to look up the search
# Lambda that 0-util created, by name.
variable "util_project_name" {
  type    = string
  default = "schematical_agent_demo"
}
