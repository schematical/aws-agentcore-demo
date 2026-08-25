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
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      # Both calls MUST use the same aws binary, and it MUST be one built
      # from AWS's 2026-08-04 service-model update - older builds either
      # reject --vector-index-updates outright ("Unknown options") or, worse,
      # accept describe-table fine but omit Table.VectorIndexes from the
      # response entirely, which makes the poll below read null forever
      # ("index status: None") even though the index is really being created.
      # Rather than trust whatever `aws` resolves to first on $PATH, probe
      # every aws binary found (plus one known-good fallback location) and
      # pin whichever one actually recognizes the flag.
      mapfile -t candidates < <(type -a -p aws 2>/dev/null)
      candidates+=("/home/user1a/.local/bin/aws")

      AWS_BIN=""
      for candidate in "$${candidates[@]}"; do
        [ -x "$candidate" ] || continue
        if AWS_PAGER="" "$candidate" dynamodb update-table help 2>&1 | grep -q -- '--vector-index-updates'; then
          AWS_BIN="$candidate"
          break
        fi
      done

      if [ -z "$AWS_BIN" ]; then
        echo "ERROR: no aws CLI found that supports DynamoDB vector indexes." >&2
        echo "That requires the service-model update AWS released 2026-08-04 - upgrade with: pip install --upgrade awscli" >&2
        echo "Checked: $${candidates[*]}" >&2
        exit 1
      fi

      echo "Using aws CLI: $AWS_BIN ($("$AWS_BIN" --version 2>&1))"

      "$AWS_BIN" dynamodb update-table \
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
      max_attempts=90  # 90 * 10s = 15 minutes
      attempt=0
      while true; do
        attempt=$((attempt + 1))
        raw=$("$AWS_BIN" dynamodb describe-table \
          --table-name "${aws_dynamodb_table.knowledge_base.name}" \
          --region "${var.region}" \
          --query 'Table.VectorIndexes[0]' \
          --output json)

        status=$(echo "$raw" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("IndexStatus") if d else "MISSING")' 2>/dev/null || echo "PARSE_ERROR")

        echo "  [$attempt/$max_attempts] index status: $status ($raw)"
        if [ "$status" = "ACTIVE" ]; then
          break
        fi
        if [ "$status" = "MISSING" ] && [ "$attempt" -ge 3 ]; then
          echo "ERROR: Table.VectorIndexes is empty/absent after $attempt attempts." >&2
          echo "This usually means the aws CLI used here doesn't know about vector indexes yet (check the version printed above) or the create call above actually failed/was rejected async - check CloudTrail for UpdateTable on this table." >&2
          exit 1
        fi
        if [ "$attempt" -ge "$max_attempts" ]; then
          echo "ERROR: timed out after $max_attempts attempts waiting for ACTIVE (last status: $status)." >&2
          exit 1
        fi
        sleep 10
      done
    EOT
  }
}
