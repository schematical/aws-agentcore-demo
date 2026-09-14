---
name: terraform-diagram
description: Analyzes a directory of Terraform (.tf) files, draws a Mermaid dependency diagram of its resources/data sources/modules, renders it to a PNG, and uploads the PNG to S3. 
Use when the user asks to diagram, visualize, or explain the structure of a Terraform configuration, or mentions terraform diagram, infrastructure diagram, or dependency graph.
---

# Terraform Diagram

## Setup
```bash
pip install mermaidx
```

## Usage:
DO the following but replace the mermaidJS syntax with what the mermaidJS code you created to represent the terraform scripts.
```python
import mermaidx

d = mermaidx.render("""
graph TD
    A[Install] --> B[Import]
    B --> C[Convert]
    C --> D[Done]
""")


d.save("diagram.png", scale=2.0)
```

## Upload To S3:
Once you are done upload the resulting `diagram.png` to S3 and supply the user with its location.

Use the AWS cli:

```bash
aws s3 cp diagram.png s3://${aws_s3_bucket.diagrams.bucket}/skills/terraform-diagram/diagram.png
```