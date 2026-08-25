# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A staged, on-camera build-up of an AWS Bedrock AgentCore Harness — from a bare-bones agent to one with memory, tools, and an MCP Gateway backing a real DynamoDB vector-search knowledge base. See `README.md` for the full stage-by-stage design doc; it's the source of truth for the architecture and demo narrative, not just a description of it.

## Repo layout

One folder per demo stage, plus a shared prerequisite and a standalone reference build — each an independent Terraform root (own `terraform/` subdir, own local state):

- `0-util/` — shared prerequisite, applied once, up front (not itself a demo stage — it's slow, since vector index creation polls for `ACTIVE`).
  - `terraform/dynamodb_knowledge_base.tf` — the knowledge-base DynamoDB table (on-demand billing, streams enabled) plus a `null_resource`/`local-exec` that creates its vector index via `aws dynamodb update-table --vector-index-updates` (the `hashicorp/aws` provider has no native vector-index support yet) and polls until `ACTIVE`.
  - `terraform/lambda_vectorize.tf` / `terraform/lambda_search.tf` — the two Lambdas (source zipped from `../build/dynamo-lambda/` and `../build/dynamo-lambda-search/`): `vectorize` consumes the table's DynamoDB Stream and writes back Titan embeddings; `search` embeds a query and runs `dynamodb:SearchVectors`. Both have active X-Ray tracing and structured `console.log` lines.
  - `build/` — the two Lambdas' JS source. `scripts/` — `seed_knowledge_base_from_rss.js`, a one-time manual utility that seeds the table from the `schematical.com` RSS feed.
- `1-bare-harness/`, `2-memory/`, `3-browser-tool/` — Stages 1-3. Each is a **complete, independently-applicable snapshot** of the harness at that stage (not commented-out blocks in a shared file) — `terraform/main.tf` holds the `aws_bedrockagentcore_harness` resource, `terraform/iam.tf` its execution role. Each stage builds on the previous by literally being a fuller copy of it (Stage 2 = Stage 1 + memory; Stage 3 = Stage 2 + browser tool).
- `4-mcp-gateway/` — Stage 4. Provisions the Gateway's own AWS resources (`terraform/gateway.tf`: `aws_bedrockagentcore_gateway` + `gateway_target` pointing at `0-util`'s `search` Lambda via a cross-root `data "aws_lambda_function"` in `terraform/lambda_data.tf`) *and* the harness with every tool active (`terraform/main.tf`, `terraform/iam_harness.tf`), reading the Gateway's ARN directly from the same-root resource. Also has the Gateway's CloudWatch log/trace delivery (`terraform/cloudwatch.tf`) and an SSM publish of the Gateway ARN/URL for manual/external use (`terraform/ssm.tf`).
- `final/` — a one-time, standalone, fully-wired reference build (own Terraform root, self-contained — its own copy of the util stack, Gateway, and harness, not cross-referencing the staged folders above) showing the complete end state with every stage active at once. See `final/README.md`. Built and reviewed once, not mechanically kept in sync with the staged folders afterward.
- `archive/1-agent-runtime/` — the old, pre-split layout (a single `terraform/` root with `aws_bedrockagentcore_agent_runtime`, a CodePipeline/CodeBuild pipeline, and a containerized Python agent in `build/agent/`). Superseded by the harness-based structure above; kept for history, not part of the active demo.

**Every stage/reference folder's resource names derive from that folder's own `project_name` Terraform variable** (`schematical_demo_stage1` … `stage4`, `schematical_demo_final`; `0-util` keeps the shared `schematical_agent_demo`) — this is deliberate, so multiple stages can be applied simultaneously ahead of a live presentation without IAM role / harness name collisions.

## Architecture notes

- **Stages are separate roots, not a single file with commented blocks.** This repo used to do progressive-uncomment-and-reapply within one `0-agent-harness/terraform/main.tf`; it doesn't anymore. Changing behavior in one stage does *not* automatically propagate to later stages' folders — each is a hand-maintained copy that includes the accumulated config of every earlier stage plus its own addition.
- **Cross-root references use Terraform `data` sources**, not `terraform_remote_state` — e.g. `4-mcp-gateway/terraform/lambda_data.tf`'s `data "aws_lambda_function" "search"` looks up `0-util`'s Lambda by name (via a separate `util_project_name` variable in that folder, kept distinct from its own `project_name` so the lookup targets `0-util`'s naming regardless of the Gateway stage's own naming).
- **DynamoDB vector search requires on-demand billing**: `aws_dynamodb_table.knowledge_base` (in `0-util` and `final`) must stay `PAY_PER_REQUEST` — provisioned-capacity tables don't support vector indexes.
- Each Terraform root's `terraform.tfstate`/`.tfstate.backup` are local — no remote backend. Be careful with concurrent applies across folders that share a dependency (only `4-mcp-gateway` depends on `0-util`).

## Commands

```bash
# Terraform (run from any stage folder's terraform/ subdir)
cd 0-util/terraform      # apply this first
terraform init && terraform apply

cd ../../1-bare-harness/terraform
terraform init && terraform apply
# ...then 2-memory, 3-browser-tool, 4-mcp-gateway in order

# final/ is independent of the staged folders - can be applied any time
cd final/terraform
terraform init && terraform apply

# One-time knowledge base seed (needs Node + AWS creds; run after 0-util's table/index exist)
cd 0-util/scripts && npm install
node seed_knowledge_base_from_rss.js --dry-run
```

There are no lint/test scripts configured in this repo (no CI config, no test suite).

## Required Terraform vars

None of the current stage/`final`/`0-util` folders have required (no-default) variables — everything has a sensible default. (The old `archive/1-agent-runtime/terraform/` root does require `vpc_id` and `private_subnet_mappings` via `terraform.tfvars`, but that root is archived and not part of the active demo.)
