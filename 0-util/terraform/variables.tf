variable "project_name" {
  type    = string
  default = "schematical_agent_demo"
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "embedding_model_id" {
  type    = string
  default = "amazon.titan-embed-text-v2:0"
}
variable "embedding_dimensions" {
  type    = number
  default = 1024
}
