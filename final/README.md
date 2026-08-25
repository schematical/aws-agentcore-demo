# final/

The complete, fully-wired end state of this demo — every stage's config active at once (memory, browser tool, MCP Gateway tool), plus its own copy of the Gateway and knowledge-base infrastructure. A one-time reference build with its own Terraform state, self-contained (no data-source references into the staged `0-util`/`1-bare-harness`/`2-memory`/`3-browser-tool`/`4-mcp-gateway` folders at the repo root).

This is the design target the staged folders are hand-authored to arrive at — it's built and reviewed once, not mechanically kept in sync afterward. If the staged folders drift from what's here, that's expected; update this tree by hand if the target architecture itself changes.

```bash
cd final/terraform
terraform init
terraform apply
```

Resources here are named off `project_name` (default `schematical_demo_final`), independent of every staged folder's own naming, so this can be applied alongside any or all of the staged folders without collisions.
