# final/

The complete, fully-wired end state of this demo — every stage's config active at once (memory, browser tool, MCP Gateway tool), plus its own copy of the Gateway infrastructure. A one-time reference build with its own Terraform state, but **not** fully standalone: it shares `0-util`'s DynamoDB table and Lambdas via a cross-root `data "aws_lambda_function"` lookup (`lambda_data.tf`), the same pattern `4-mcp-gateway` uses, rather than duplicating that stack. `0-util` must be applied first.

This is the design target the staged folders are hand-authored to arrive at — it's built and reviewed once, not mechanically kept in sync afterward. If the staged folders drift from what's here, that's expected; update this tree by hand if the target architecture itself changes.

```bash
cd 0-util/terraform && terraform init && terraform apply   # once, if not already applied

cd ../../final/terraform
terraform init
terraform apply
```

Resources here are named off `project_name` (default `schematical-demo-final`), independent of every staged folder's own naming, so this can be applied alongside any or all of the staged folders without collisions — except `0-util`, which it depends on.
