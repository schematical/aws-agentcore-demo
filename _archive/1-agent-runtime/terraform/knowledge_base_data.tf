locals {
  vector_index_name = "${var.project_name}-vector-index"
}

data "aws_dynamodb_table" "knowledge_base" {
  name = "${var.project_name}-knowledge-base"
}
