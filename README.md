# AWS AgentCore Demo

A staged, on-camera build-up of an [AWS Bedrock AgentCore](https://aws.amazon.com/bedrock/agentcore/) Harness — from a bare-bones agent to one with memory, tools, and an MCP Gateway backing a real knowledge base. This README is the design doc: it tracks the architecture and the stage-by-stage plan for the walkthrough video.

## Architecture

One folder per demo stage, plus a shared prerequisite and a reference build — each an independent Terraform root with its own local state and lifecycle:

| Root | Owns | Depends on |
| --- | --- | --- |
| `0-util/terraform/` | The knowledge-base DynamoDB table + vector index, the `vectorize` Lambda (embeds new items on insert via DynamoDB Streams), and the `search` Lambda (embeds a query, runs `dynamodb:SearchVectors`) | nothing |
| `1-bare-harness/terraform/` | Stage 1: just the `aws_bedrockagentcore_harness` resource, no memory, no tools | nothing |
| `2-memory/terraform/` | Stage 2: harness + managed memory | nothing |
| `3-browser-tool/terraform/` | Stage 3: harness + memory + the native `agentcore_browser` tool | nothing |
| `4-mcp-gateway/terraform/` | Stage 4: the `aws_bedrockagentcore_gateway` (MCP server) + `gateway_target` pointing at `0-util`'s `search` Lambda, **plus** the harness with every tool active | `0-util` |
| `final/terraform/` | A one-time reference build (own state) showing the complete end state — every stage's config active at once, plus its own Gateway — see `final/README.md` | `0-util` |

Each stage folder is a **complete, independently-applicable snapshot** of the infra as it looks after that stage — not a shared file with commented-out blocks for later stages. This means every stage can be pre-applied ahead of a live presentation and left standing, so the demo just switches which harness it's showing instead of running `terraform apply`/`destroy` on camera. That only works because every stage's resources (harness, IAM roles, etc.) are named off that folder's own `project_name` variable (`schematical-demo-stage1` … `stage4`) — no two stages share a resource name, so applying several at once doesn't collide.

`0-util` is a shared prerequisite, not itself a demo stage — it's slow (vector index creation polls for `ACTIVE`), so it gets applied once, up front, before the on-camera walkthrough starts. `4-mcp-gateway` and `final` both depend on it (via a `data "aws_lambda_function"` cross-root lookup, looking up `0-util`'s Lambda by name) rather than keeping their own copy of the DynamoDB/Lambda stack.

**Apply order**: `0-util` (once, up front) → `1-bare-harness` → `2-memory` → `3-browser-tool` → `4-mcp-gateway` → `final`. Stages 1-3 need nothing but their own folder; Stage 4 and `final` both need `0-util` already applied.

## Demo stages

### Stage 1 — bare harness (`1-bare-harness/`)

Just the `aws_bedrockagentcore_harness` resource with a model, a system prompt, and truncation settings. `memory { disabled {} }` is explicit — no memory, no tools. This is the starting point: the smallest thing that's a working agent.

### Stage 2 — memory (`2-memory/`)

Same harness, but `memory { managed_memory_configuration { ... } }` replaces `disabled {}`. Fully self-contained in the harness resource — no separate AWS resource to provision or explain, just one block swap that turns on semantic + summarization memory.

### Stage 3 — a basic tool call (browser) (`3-browser-tool/`)

Adds the `tool { type = "agentcore_browser" }` block. AWS runs the browsing loop itself — no `browser_arn` needed (defaults to an AWS-managed browser), no container or agent code to write. This is the first tool call demo: show the harness deciding to browse and use the result.

### Stage 4 — the MCP Gateway (`4-mcp-gateway/`)

Requires `0-util` to already be applied. This folder provisions the Gateway's own AWS resources (`aws_bedrockagentcore_gateway` + `gateway_target`, pointing at `0-util`'s `search` Lambda) *and* the harness with the `agentcore_gateway` tool block active, reading the Gateway's ARN directly from the resource in the same root. This is where the demo connects the harness to the knowledge base: a query comes in through MCP, the Gateway routes it to the `search` Lambda, which embeds the query and runs a DynamoDB vector search.

### Stage 5 — evaluations

Not yet designed. See Roadmap below.

## Observability

- **Both Lambdas** (`vectorize`, `search`, in `0-util/terraform/`) have active X-Ray tracing (`tracing_config { mode = "Active" }`) and structured `console.log` lines (query text, per-call timings, result counts) — visible in their own `/aws/lambda/...` CloudWatch Log groups.
- **The Gateway** has explicit CloudWatch log delivery configured (`4-mcp-gateway/terraform/cloudwatch.tf`, mirrored in `final/terraform/cloudwatch.tf`) — Gateway resources don't get a log destination by default the way the old agent runtime did. X-Ray trace delivery for the Gateway isn't wired up yet — it requires the account-wide Transaction Search setting below to be enabled first, or `aws_cloudwatch_log_delivery` creation fails with a `ValidationException`.
- **Not done yet**: account-wide CloudWatch Transaction Search (needed for the full cross-service GenAI Observability dashboard — a distributed-trace view spanning harness → gateway → Lambda), and harness-level tracing (AWS's console has a per-resource "Tracing" toggle for this, but no equivalent field was found on `aws_bedrockagentcore_harness` in the `hashicorp/aws` provider yet). Both are real, account/account-wide-affecting changes that were deliberately left out of this pass rather than guessed at — see Roadmap.
## Export:

```
agentcore export harness --name schematical-demo-final-harness
```

## Roadmap / not yet designed

- **Auth** — will likely be needed once the Gateway is reachable by something other than the harness's own execution role. The `agentcore_gateway` tool type has an `outbound_auth` option that's the probable home for this, but the actual design (what's authenticating to what, and how) hasn't happened yet.
- **Account-wide CloudWatch Transaction Search** — a one-time, account-level setting (X-Ray trace-segment destination + a CloudWatch Logs resource policy) required for the full GenAI Observability dashboard and any true cross-service trace correlation. Not enabled here since it affects the whole AWS account, not just this project.
- **Harness-level tracing toggle** — AWS's console exposes this per-resource; no Terraform field found for it yet.
- **Evaluations (Stage 5)** — not designed yet. Whether this is a Terraform-managed resource or an external process (running eval jobs against recorded transcripts) is still open.
