import json
import os
from typing import Any, Dict

import boto3
from strands import tool
from rich.console import Console

console = Console()

KNOWLEDGE_BASE_TABLE_NAME = os.getenv("KNOWLEDGE_BASE_TABLE_NAME")
KNOWLEDGE_BASE_INDEX_NAME = os.getenv("KNOWLEDGE_BASE_INDEX_NAME")
EMBEDDING_MODEL_ID = os.getenv("EMBEDDING_MODEL_ID")
EMBEDDING_DIMENSIONS = int(os.getenv("EMBEDDING_DIMENSIONS", "1024"))
AWS_REGION = os.getenv("AWS_REGION")


def _embed(bedrock_runtime, text: str) -> list:
    response = bedrock_runtime.invoke_model(
        modelId=EMBEDDING_MODEL_ID,
        body=json.dumps(
            {
                "inputText": text,
                "dimensions": EMBEDDING_DIMENSIONS,
                "normalize": True,
            }
        ),
    )
    return json.loads(response["body"].read())["embedding"]


@tool
async def search_knowledge_base(query: str) -> Dict[str, Any]:
    """Search the knowledge base of schematical.com blog posts for content relevant to the query."""
    try:
        console.print(f"[cyan]📚 Searching knowledge base for:[/cyan] {query[:100]}...")

        bedrock_runtime = boto3.client("bedrock-runtime", region_name=AWS_REGION)
        dynamodb = boto3.client("dynamodb", region_name=AWS_REGION)

        embedding = _embed(bedrock_runtime, query)

        response = dynamodb.search_vectors(
            TableName=KNOWLEDGE_BASE_TABLE_NAME,
            IndexName=KNOWLEDGE_BASE_INDEX_NAME,
            SearchVector=[{"N": str(v)} for v in embedding],
            TopK=3,
        )

        results = response.get("SearchResults", [])
        if not results:
            return {"status": "success", "content": [{"text": "No relevant knowledge base entries found."}]}

        lines = []
        for result in results:
            item = result.get("Item", {})
            title = item.get("title", {}).get("S", "")
            text = item.get("text", {}).get("S", "")
            category = item.get("category", {}).get("S", "")
            score = result.get("Score")
            lines.append(f"- {title} (category: {category}, score: {score}): {text[:300]}")

        console.print(f"[green]✅ Found {len(results)} knowledge base result(s)[/green]")
        return {"status": "success", "content": [{"text": "\n".join(lines)}]}

    except Exception as e:
        console.print(f"[red]❌ Error searching knowledge base: {e}[/red]")
        return {
            "status": "error",
            "content": [{"text": f"Error searching knowledge base: {str(e)}"}],
        }
