data "archive_file" "search_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../build/dynamo-lambda-search"
  output_path = "${path.module}/.artifacts/search_lambda.zip"
}

resource "aws_iam_role" "search_lambda" {
  name = "${var.project_name}-search-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AssumeRolePolicy"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name   = "${var.project_name}-search-lambda-role"
    Module = "KnowledgeBase"
  }
}

resource "aws_iam_role_policy_attachment" "search_lambda_basic_execution" {
  role       = aws_iam_role.search_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "search_lambda_xray" {
  role       = aws_iam_role.search_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "search_lambda" {
  name = "SearchLambdaPolicy"
  role = aws_iam_role.search_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SearchKnowledgeBaseVectors"
        Effect   = "Allow"
        Action   = ["dynamodb:SearchVectors"]
        Resource = "${aws_dynamodb_table.knowledge_base.arn}/index/${local.vector_index_name}"
      },
      {
        Sid      = "TitanEmbeddingInvocation"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "search" {
  function_name = "${var.project_name}-search-knowledge-base"
  role          = aws_iam_role.search_lambda.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  filename         = data.archive_file.search_lambda.output_path
  source_code_hash = data.archive_file.search_lambda.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME           = aws_dynamodb_table.knowledge_base.name
      INDEX_NAME           = local.vector_index_name
      EMBEDDING_MODEL_ID   = var.embedding_model_id
      EMBEDDING_DIMENSIONS = tostring(var.embedding_dimensions)
    }
  }

  tags = {
    Name   = "${var.project_name}-search-knowledge-base"
    Module = "KnowledgeBase"
  }
}
