"use strict";

// @aws-sdk/client-dynamodb and @aws-sdk/client-bedrock-runtime ship with the
// Lambda Node.js managed runtime (v3 SDK) - no node_modules/npm install
// needed to package this, same as the previous Python handler relying on
// Lambda's bundled boto3.
const { DynamoDBClient, UpdateItemCommand } = require("@aws-sdk/client-dynamodb");
const { BedrockRuntimeClient, InvokeModelCommand } = require("@aws-sdk/client-bedrock-runtime");

const TABLE_NAME = process.env.TABLE_NAME;
const EMBEDDING_MODEL_ID = process.env.EMBEDDING_MODEL_ID;
const EMBEDDING_DIMENSIONS = parseInt(process.env.EMBEDDING_DIMENSIONS, 10);

const dynamodb = new DynamoDBClient({});
const bedrockRuntime = new BedrockRuntimeClient({});

async function embed(text) {
  const response = await bedrockRuntime.send(
    new InvokeModelCommand({
      modelId: EMBEDDING_MODEL_ID,
      body: JSON.stringify({
        inputText: text,
        dimensions: EMBEDDING_DIMENSIONS,
        normalize: true,
      }),
    })
  );
  const body = JSON.parse(Buffer.from(response.body).toString("utf8"));
  return body.embedding;
}

exports.handler = async (event) => {
  for (const record of event.Records || []) {
    if (record.eventName !== "INSERT" && record.eventName !== "MODIFY") continue;

    const image = (record.dynamodb && record.dynamodb.NewImage) || {};
    const itemId = image.id && image.id.S;
    const text = image.text && image.text.S;

    if (!itemId || !text) continue;

    // Writing the embedding back to the table re-triggers this same
    // stream, so skip items that are already vectorized for this text to
    // avoid an infinite embed -> write -> re-trigger loop.
    if ("embedding" in image) {
      console.log(JSON.stringify({ msg: "vectorize skipped (already embedded)", itemId }));
      continue;
    }

    const embedStart = Date.now();
    const embedding = await embed(text);
    const embedMs = Date.now() - embedStart;

    await dynamodb.send(
      new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: { id: { S: itemId } },
        UpdateExpression: "SET embedding = :emb",
        ExpressionAttributeValues: {
          ":emb": { L: embedding.map((v) => ({ N: String(v) })) },
        },
      })
    );

    console.log(JSON.stringify({ msg: "vectorize completed", itemId, embedMs }));
  }

  return { statusCode: 200 };
};
