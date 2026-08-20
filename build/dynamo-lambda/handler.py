import json
import os

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
EMBEDDING_MODEL_ID = os.environ["EMBEDDING_MODEL_ID"]
EMBEDDING_DIMENSIONS = int(os.environ["EMBEDDING_DIMENSIONS"])

dynamodb = boto3.client("dynamodb")
bedrock_runtime = boto3.client("bedrock-runtime")


def embed(text: str) -> list:
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


def handler(event, context):
    for record in event.get("Records", []):
        if record.get("eventName") not in ("INSERT", "MODIFY"):
            continue

        image = record["dynamodb"].get("NewImage", {})
        item_id = image.get("id", {}).get("S")
        text = image.get("text", {}).get("S")

        if not item_id or not text:
            continue

        # Writing the embedding back to the table re-triggers this same
        # stream, so skip items that are already vectorized for this text to
        # avoid an infinite embed -> write -> re-trigger loop.
        if "embedding" in image:
            continue

        embedding = embed(text)

        dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={"id": {"S": item_id}},
            UpdateExpression="SET embedding = :emb",
            ExpressionAttributeValues={
                ":emb": {"L": [{"N": str(v)} for v in embedding]}
            },
        )

    return {"statusCode": 200}
