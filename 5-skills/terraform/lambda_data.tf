# Owned by 0-util/terraform - that root must be applied first, or this lookup
# fails with "couldn't find resource". Uses util_project_name (not this
# folder's own project_name) since it must match 0-util's naming, not this
# stage's.
data "aws_lambda_function" "search" {
  function_name = "${var.util_project_name}-search-knowledge-base"
}
