"use strict";

// DynamoDB vector search (SearchVectorsCommand) GA'd very recently, so unlike
// the vectorize handler (which only needs the long-stable UpdateItemCommand),
// this handler can't rely on the AWS SDK v3 version bundled with the Lambda
// Node.js managed runtime - @aws-sdk/client-dynamodb must be vendored into
// node_modules before this directory is zipped (`npm install` in this dir).
const { DynamoDBClient, SearchVectorsCommand } = require("@aws-sdk/client-dynamodb");
const { BedrockRuntimeClient, InvokeModelCommand } = require("@aws-sdk/client-bedrock-runtime");

const TABLE_NAME = process.env.TABLE_NAME;
const INDEX_NAME = process.env.INDEX_NAME;
const EMBEDDING_MODEL_ID = process.env.EMBEDDING_MODEL_ID;
const EMBEDDING_DIMENSIONS = parseInt(process.env.EMBEDDING_DIMENSIONS, 10);
const TOP_K = 3;

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

// The Gateway hands the tool's input arguments to the Lambda directly as
// `event` (not nested under an "input"/"arguments" key).
exports.handler = async (event) => {
  const query = event && event.query;
  console.log(JSON.stringify({ msg: "search_knowledge_base invoked", query }));

  if (!query) {
    return { results: [], error: "Missing required 'query' argument." };
  }

  const embedStart = Date.now();
  const embedding = await embed(query);
  const embedMs = Date.now() - embedStart;

  const searchStart = Date.now();
  const response = await dynamodb.send(
    new SearchVectorsCommand({
      TableName: TABLE_NAME,
      IndexName: INDEX_NAME,
      SearchVector: embedding.map((v) => ({ N: String(v) })),
      TopK: TOP_K,
    })
  );
  const searchMs = Date.now() - searchStart;

  const results = (response.SearchResults || []).map((result) => {
    const item = result.Item || {};
    return {
      title: (item.title && item.title.S) || "",
      text: (item.text && item.text.S) || "",
      category: (item.category && item.category.S) || "",
      score: result.Score,
    };
  });

  console.log(
    JSON.stringify({
      msg: "search_knowledge_base completed",
      query,
      embedMs,
      searchMs,
      resultCount: results.length,
    })
  );

  return { results };
};
