
resource "aws_s3_bucket" "skills" {
  bucket = "${var.project_name}-skills-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name   = "${var.project_name}-skills"
    Module = "Skills"
  }
}

resource "aws_s3_bucket_public_access_block" "diagrams" {
  bucket = aws_s3_bucket.skills.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}




resource "aws_s3_object" "skill_files" {


  bucket = aws_s3_bucket.skills.id
  key    = "skills/poem/SKILL.md"
  source = "${path.module}/../skills/poem/SKILL.md"
  etag   = filemd5("${path.module}/../skills/poem/SKILL.md")
}


resource "aws_ssm_parameter" "diagram_bucket_name" {
  name  = "/${var.project_name}/poem/s3-bucket"
  type  = "String"
  value = aws_s3_bucket.skills.bucket

  tags = {
    Name   = "${var.project_name}-terraform-diagram-bucket-name"
    Module = "Skills"
  }
}
