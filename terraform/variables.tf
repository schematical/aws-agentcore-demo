variable "project_name" {
  type = string
  default = "schematical_agent_demo"
}
variable "env" {
  type = string
  default = "dev"
}
variable "region" {
  type = string
  default = "us-east-1"
}
variable "vpc_id" {
  type = string
  //TODO: Put in your default vpc id if nothing else.
}
variable "private_subnet_mappings" {
  type = map(any)
}
variable "github_owner" {
  type = string
  default = "schematical"
}
variable "github_project_name" {
  type = string
  default = "aws-agentcore-demo"
}
variable "codepipeline_bucket" {
  default = "agent-demo-codepipeline"
  type = string
}
variable "embedding_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}
variable "embedding_dimensions" {
  type    = number
  default = 1024
}