locals {
  knowledge_base_table_name = "${var.project_name}-knowledge-base"
  vector_index_name         = "${var.project_name}-vector-index"
}

# On-demand (PAY_PER_REQUEST) billing is required for DynamoDB vector search -
# provisioned-capacity tables do not support vector indexes.
# https://aws.amazon.com/blogs/aws/amazon-dynamodb-now-supports-real-time-vector-search-at-any-scale/
resource "aws_dynamodb_table" "knowledge_base" {
  name         = local.knowledge_base_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  tags = {
    Name   = local.knowledge_base_table_name
    Module = "KnowledgeBase"
  }
}

# The hashicorp/aws provider has no vector-index support yet (GA'd 2026-08-05,
# too new for the provider schema - confirmed no vector_index/Dimensions/
# DistanceFunction args on aws_dynamodb_table). Same class of gap this repo
# already works around for the agent runtime image update in buildspec.yml -
# create the index out-of-band via the AWS CLI and poll until ACTIVE, since
# there's no waiter for vector index creation.
resource "null_resource" "knowledge_base_vector_index" {
  depends_on = [aws_dynamodb_table.knowledge_base]

  triggers = {
    table_name = aws_dynamodb_table.knowledge_base.name
    index_name = local.vector_index_name
    dimensions = var.embedding_dimensions
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      aws dynamodb update-table \
        --table-name "${aws_dynamodb_table.knowledge_base.name}" \
        --region "${var.region}" \
        --vector-index-updates '[
          {
            "Create": {
              "IndexName": "${local.vector_index_name}",
              "VectorAttribute": {"AttributeName": "embedding"},
              "Dimensions": ${var.embedding_dimensions},
              "DistanceFunction": "COSINE",
              "Projection": {"ProjectionType": "ALL"}
            }
          }
        ]'

      echo "Waiting for vector index ${local.vector_index_name} to become ACTIVE..."
      while true; do
        status=$(aws dynamodb describe-table \
          --table-name "${aws_dynamodb_table.knowledge_base.name}" \
          --region "${var.region}" \
          --query 'Table.VectorIndexes[0].IndexStatus' \
          --output text)

        echo "  index status: $status"
        if [ "$status" = "ACTIVE" ]; then
          break
        fi
        sleep 5
      done
    EOT
  }
}
