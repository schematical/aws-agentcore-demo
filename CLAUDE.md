# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A demo of AWS Bedrock AgentCore: Terraform provisions an AgentCore Runtime (containerized agent), Browser tool, Memory resource, and a DynamoDB vector-search knowledge base; a CodePipeline/CodeBuild pipeline (defined in an external module) builds and deploys the agent container from `build/agent/`. The agent itself is a Python `strands-agents` Agent that uses `browser_use` + AgentCore's managed Browser tool to drive a headless browser via Bedrock-hosted Claude, exposed through `bedrock_agentcore.runtime.BedrockAgentCoreApp`.

Per README.md, this is a work-in-progress demo touching: Memory, Evaluations, Observability, Browser, MCP connection (most still unchecked/TODO).

## Repo layout

- `terraform/` — the Terraform root module (all `*.tf` files, `terraform.tfvars`, state, and the provider lock file live here — no submodules within this repo):
  - `main.tf` — ECR repo (+ policy/lifecycle), S3 artifact bucket, the `aws_bedrockagentcore_agent_runtime` resource, and the `buildpipeline` module (pulled from `github.com/schematical/sc-terraform//modules/buildpipeline`, an external repo — not vendored here).
  - `agentcore_browser.tf`, `agentcore_memory.tf` — the AgentCore Browser and Memory resources referenced by the runtime's env vars (`BROWSER_ID`, `MEMORY_ID`).
  - `dynamodb_knowledge_base.tf` — the knowledge-base DynamoDB table (on-demand billing, streams enabled) plus a `null_resource`/`local-exec` that creates its vector index via `aws dynamodb update-table --vector-index-updates` (the `hashicorp/aws` provider has no native vector-index support yet) and polls until `ACTIVE`.
  - `lambda_vectorize.tf` — the Lambda (source zipped from `../build/dynamo-lambda/`) that consumes the knowledge-base table's DynamoDB Stream and writes back Titan embeddings.
  - `iam.tf` — the agent execution role (assumed by `bedrock-agentcore.amazonaws.com`), the vectorize Lambda's role, and an inline policy attached to the CodeBuild role created by the `buildpipeline` module.
  - `cloudwatch.tf` — log group + CloudWatch Logs delivery pipeline (source → destination → delivery) wiring AgentCore runtime application logs to CloudWatch.
  - `variables.tf` — inputs; `vpc_id` and `private_subnet_mappings` have no defaults and must be supplied via `terraform.tfvars` (see `terraform.tfvars.example`, currently empty — check `terraform.tfvars`, gitignored, for real values).
- `build/` — everything built/pushed by the pipeline, or run manually against the deployed infra:
  - `build/agent/` — the agent container source (this is the Docker build context, and what `buildspec.yml` deploys):
    - `main.py` — the agent entrypoint (`BedrockAgentCoreApp`), which wires up `tools/` and handles per-request actor/session context.
    - `tools/` — one file per Strands tool (`browser.py`, `memory.py`, `knowledge_base.py`).
    - `Dockerfile` — `python:3.11-slim`, ARM64 target, runs as non-root user `bedrock_agentcore`, launched via `opentelemetry-instrument python -m main`.
    - `requirements.txt` — no pinned versions except `browser-use==0.3.2`, `langchain-aws>=0.1.0`, and `botocore>=1.43.64` (floor for DynamoDB `SearchVectors` support).
  - `build/dynamo-lambda/` — source for the vectorize Lambda (`handler.py`), zipped by `terraform/lambda_vectorize.tf`. Not part of the agent container.
- `scripts/seed_knowledge_base_from_rss.py` — one-time, manually-run utility that seeds the knowledge base table from the `schematical.com` RSS feed; not deployed anywhere.
- `buildspec.yml` — CodeBuild spec (stays at repo root — the pipeline module points at it by path within the checked-out source repo): builds/pushes the Docker image from `build/agent/` to ECR (tagged `$IMAGE_TAG`, i.e. `$env`), then calls `aws bedrock-agentcore-control update-agent-runtime` directly via the CLI to point the runtime at the new image (Terraform does not manage this update — the pipeline does, out-of-band, after each build).

## Architecture notes

- **Deploy flow is two-stage and asymmetric**: `terraform apply` (from `terraform/`) provisions the runtime, ECR repo, IAM, Browser, Memory, knowledge-base table/Lambda, and the CodePipeline/CodeBuild pipeline itself — but the *container image* the runtime points at is only updated by the pipeline running `buildspec.yml` (triggered by a push to the `main` branch of the GitHub repo configured via `github_owner`/`github_project_name`). Editing `build/agent/` and running `terraform apply` alone does not deploy new agent code.
- **IAM ordering coupling**: `iam.tf`'s `aws_iam_role_policy.codebuild` reaches into `module.buildpipeline.code_build_iam_role` and `aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id`, so IAM, the runtime, and the pipeline module are mutually order-dependent — expect this if you see plan/apply ordering issues.
- **Runtime env vars** (`BROWSER_ID`, `MEMORY_ID`, `MEMORY_STRATEGY_ID`, `KNOWLEDGE_BASE_TABLE_NAME`, `KNOWLEDGE_BASE_INDEX_NAME`, `EMBEDDING_MODEL_ID`, `EMBEDDING_DIMENSIONS`, `AWS_REGION` in `main.tf`) are the wiring between Terraform-provisioned AgentCore resources and `build/agent/main.py`/`tools/`, which read them via `os.getenv`. If you add a new AgentCore resource the agent needs, wire it through this `environment_variables` block.
- **DynamoDB vector search requires on-demand billing**: `aws_dynamodb_table.knowledge_base` must stay `PAY_PER_REQUEST` — provisioned-capacity tables don't support vector indexes.
- Several resources/blocks are commented out mid-file (`time_sleep.wait_for_codebuild`, `aws_default_vpc`, usage-logs delivery) — these are deliberate not-yet-enabled pieces, not dead code to delete without checking history/intent first.
- `terraform/terraform.tfstate`/`.tfstate.backup` are present in the working tree but `.gitignore`'d — local/demo state, not a remote backend. Be careful with concurrent applies.

## Commands

```bash
# Terraform (run from terraform/)
cd terraform
terraform init
terraform plan
terraform apply

# Agent container build (matches buildspec.yml; must be arm64 to match the CodeBuild pipeline)
cd build/agent
docker build --platform linux/arm64 -t <repo>:<tag> .

# One-time knowledge base seed (needs boto3 + AWS creds; run after the table/index exist)
python3 scripts/seed_knowledge_base_from_rss.py --dry-run
```

There are no lint/test scripts configured in this repo (no CI config beyond `buildspec.yml`, no test suite in `build/`).

## Required Terraform vars

`vpc_id` and `private_subnet_mappings` have no defaults and must be set in `terraform/terraform.tfvars` (see the shape used in the existing, gitignored `terraform/terraform.tfvars`; `terraform/terraform.tfvars.example` is currently empty).
