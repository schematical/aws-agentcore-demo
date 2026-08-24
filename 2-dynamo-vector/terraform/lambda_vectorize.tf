data "archive_file" "vectorize_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../build/dynamo-lambda"
  output_path = "${path.module}/.artifacts/vectorize_lambda.zip"
}

resource "aws_iam_role" "vectorize_lambda" {
  name = "${var.project_name}-vectorize-lambda-role"

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
    Name   = "${var.project_name}-vectorize-lambda-role"
    Module = "KnowledgeBase"
  }
}

resource "aws_iam_role_policy_attachment" "vectorize_lambda_dynamodb_stream" {
  role       = aws_iam_role.vectorize_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
}

resource "aws_iam_role_policy" "vectorize_lambda" {
  name = "VectorizeLambdaPolicy"
  role = aws_iam_role.vectorize_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UpdateKnowledgeBaseItem"
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.knowledge_base.arn
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

resource "aws_lambda_function" "vectorize" {
  function_name = "${var.project_name}-vectorize-knowledge-base"
  role          = aws_iam_role.vectorize_lambda.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  filename         = data.archive_file.vectorize_lambda.output_path
  source_code_hash = data.archive_file.vectorize_lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME           = aws_dynamodb_table.knowledge_base.name
      EMBEDDING_MODEL_ID    = var.embedding_model_id
      EMBEDDING_DIMENSIONS  = tostring(var.embedding_dimensions)
    }
  }

  tags = {
    Name   = "${var.project_name}-vectorize-knowledge-base"
    Module = "KnowledgeBase"
  }
}

resource "aws_lambda_event_source_mapping" "vectorize_stream" {
  event_source_arn  = aws_dynamodb_table.knowledge_base.stream_arn
  function_name     = aws_lambda_function.vectorize.arn
  starting_position = "LATEST"
}
