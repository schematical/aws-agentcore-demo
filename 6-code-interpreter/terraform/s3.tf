# Dual-purpose bucket: (1) the terraform-diagram skill uploads its rendered
# PNGs here (see ../skills/terraform-diagram/scripts/analyze.py), under the
# terraform-diagrams/ prefix, and (2) the skill's own SOURCE FILES
# (SKILL.md, scripts/) are uploaded here too, under skills/terraform-diagram/
# - see aws_s3_object.skill_files below - so the harness's `s3` skill source
# can fetch them (path-source skills need a container-image bake or
# session-start command; s3-source skills are fetched by AgentCore itself,
# no extra plumbing needed - see README.md's Roadmap section). Bucket name
# includes the account id since S3 bucket names are globally unique across
# all AWS accounts, not just within this one.
resource "aws_s3_bucket" "diagrams" {
  bucket = "${var.project_name}-diagrams-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name   = "${var.project_name}-diagrams"
    Module = "Skills"
  }
}

# Kept private - the skill generates presigned GetObject URLs at upload time
# (see analyze.py) rather than serving objects via a public bucket policy,
# so no public access or static-website-hosting config is needed here.
resource "aws_s3_bucket_public_access_block" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Rendered diagrams are throwaway demo output, not worth keeping indefinitely
# - matches this repo's general cost-consciousness (see README.md's "A note
# on costs").
resource "aws_s3_bucket_lifecycle_configuration" "diagrams" {
  bucket = aws_s3_bucket.diagrams.id

  rule {
    id     = "expire-rendered-diagrams"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# Uploads the skill's own source files (SKILL.md, scripts/) to the bucket
# under skills/terraform-diagram/, so the harness's `s3` skill source (set
# via skill_registration.tf's UpdateHarness call, not the native `skill`
# block - the Terraform provider only supports the `path` source type) can
# fetch them at session start. fileset() picks up every file under the
# skill's local directory automatically, so adding a new file to the skill
# doesn't require a matching new resource here - excludes .venv/__pycache__
# (created by locally running scripts/setup.sh /analyze.py, never meant to
# be uploaded) since fileset() has no built-in exclude pattern.
locals {
  skill_files = {
    for f in fileset("${path.module}/../skills/terraform-diagram", "**") :
    f => f if !strcontains(f, "/.venv/") && !strcontains(f, "/__pycache__/")
  }
}

resource "aws_s3_object" "skill_files" {
  for_each = local.skill_files

  bucket = aws_s3_bucket.diagrams.id
  key    = "skills/terraform-diagram/${each.value}"
  source = "${path.module}/../skills/terraform-diagram/${each.value}"
  etag   = filemd5("${path.module}/../skills/terraform-diagram/${each.value}")
}

# Published so the skill's script can discover the bucket name at runtime
# (via `aws ssm get-parameter` or boto3) without it being hardcoded or
# templated into SKILL.md/analyze.py - same pattern as this folder's
# gateway_arn/gateway_url SSM publishes.
resource "aws_ssm_parameter" "diagram_bucket_name" {
  name  = "/${var.project_name}/terraform-diagram/s3-bucket"
  type  = "String"
  value = aws_s3_bucket.diagrams.bucket

  tags = {
    Name   = "${var.project_name}-terraform-diagram-bucket-name"
    Module = "Skills"
  }
}
