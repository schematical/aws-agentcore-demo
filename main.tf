resource "aws_bedrockagentcore_agent_runtime" "agent" {
  agent_runtime_name = var.project_name
  description        = "${var.project_name} agent"
  role_arn           = aws_iam_role.agent_execution.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.agent_ecr.repository_url}:${var.env}"
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  environment_variables = merge(
    {
      BROWSER_ID          = aws_bedrockagentcore_browser.browser.browser_id,
      MEMORY_ID           = aws_bedrockagentcore_memory.agentcore_memory.id
    },
    // var.environment_variables
  )

  depends_on = [
    time_sleep.wait_for_codebuild
  ]
}


resource "aws_ecr_repository" "agent_ecr" {
  name                 = "${var.project_name}-${var.env}-${var.region}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name   = "${var.project_name}-${var.env}-${var.region}"
    Module = "ECR"
  }
}


resource "aws_ecr_repository_policy" "agent_ecr" {
  repository = aws_ecr_repository.agent_ecr.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullFromAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.id}:root"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "agent_ecr" {
  repository = aws_ecr_repository.agent_ecr.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "codepipeline_artifact_store_bucket" {
  bucket = "${var.codepipeline_bucket}"
}

/*resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}*/
module "buildpipeline" {
  source = "git::https://github.com/schematical/sc-terraform.git//modules/buildpipeline"
  service_name = var.project_name
  region = var.region
  env = var.env
  github_owner = var.github_owner
  github_project_name = var.github_project_name
  github_source_branch = "main"#var.env
  code_pipeline_artifact_store_bucket = aws_s3_bucket.codepipeline_artifact_store_bucket.bucket
  vpc_id = var.vpc_id
  private_subnet_mappings = var.private_subnet_mappings # see github.com/schematical/sc-terraform/modules/vpc for this
  source_buildspec_path = "buildspec.yml"
  env_vars =  {
    IMAGE_TAG: var.env
  }
  code_build_image_uri = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
  codebuild_environment_type = "ARM_CONTAINER"
}

resource "time_sleep" "wait_for_codebuild" {
  depends_on = [
    module.buildpipeline
  ]

  create_duration = "120s"
}