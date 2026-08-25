#!/usr/bin/env node
/**
 * One-time utility to seed the knowledge base DynamoDB table from the
 * schematical.com RSS feed. Not part of any deployed container - run
 * manually from a machine with AWS credentials:
 *
 *   npm install
 *   node seed_knowledge_base_from_rss.js [--dry-run] [--limit N]
 *
 * Writes id/title/text/category only. The `embedding` attribute is
 * intentionally left unset - the DynamoDB Streams -> Lambda pipeline
 * (build/dynamo-lambda/handler.py) fills it in asynchronously after each
 * item lands in the table. Re-running is safe: ids are derived from each
 * post's URL slug, so put_item overwrites rather than duplicates.
 */

"use strict";

const https = require("https");
const crypto = require("crypto");

const FEED_URL = "https://schematical.com/api/posts.rss";
const DEFAULT_CATEGORY = "main";

const ITEM_RE = /<item>([\s\S]*?)<\/item>/g;
const TAG_RE = /<[^>]+>/g;
const WHITESPACE_RE = /\s+/g;
const CDATA_RE = /<!\[CDATA\[([\s\S]*?)\]\]>/;

const ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
};

function unescapeHtml(text) {
  return text
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(parseInt(dec, 10)))
    .replace(/&(amp|lt|gt|quot|apos|nbsp);/g, (_, name) => ENTITIES[name]);
}

function stripHtml(rawHtml) {
  const text = rawHtml.replace(TAG_RE, " ");
  return unescapeHtml(text).replace(WHITESPACE_RE, " ").trim();
}

function extractTag(block, tagPattern) {
  const match = block.match(tagPattern);
  if (!match) return "";
  const raw = match[1];
  const cdata = raw.match(CDATA_RE);
  return (cdata ? cdata[1] : raw).trim();
}

function slugFromLink(link) {
  let path;
  try {
    path = new URL(link).pathname.replace(/\/+$/, "");
  } catch {
    path = "";
  }
  const slug = path.split("/").pop();
  if (slug) return slug;
  return crypto.createHash("sha256").update(link, "utf8").digest("hex").slice(0, 16);
}

function fetchFeed(feedUrl) {
  return new Promise((resolve, reject) => {
    https
      .get(feedUrl, { headers: { "User-Agent": "seed-knowledge-base/1.0" } }, (res) => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`Request failed with status ${res.statusCode}`));
          res.resume();
          return;
        }
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
      })
      .on("error", reject);
  });
}

function parseItems(feedText) {
  const items = [];
  let match;
  while ((match = ITEM_RE.exec(feedText)) !== null) {
    const block = match[1];

    const link = extractTag(block, /<link>([\s\S]*?)<\/link>/);
    const title = extractTag(block, /<title>([\s\S]*?)<\/title>/);

    let bodyHtml = extractTag(block, /<content:encoded>([\s\S]*?)<\/content:encoded>/);
    if (!bodyHtml) {
      bodyHtml = extractTag(block, /<description>([\s\S]*?)<\/description>/);
    }

    const text = stripHtml(bodyHtml);
    const category = extractTag(block, /<category>([\s\S]*?)<\/category>/) || DEFAULT_CATEGORY;

    if (!link || !title || !text) continue;

    items.push({
      id: slugFromLink(link),
      title,
      text,
      category: category || DEFAULT_CATEGORY,
    });
  }
  return items;
}

function parseArgs(argv) {
  const args = {
    feedUrl: FEED_URL,
    tableName: process.env.KNOWLEDGE_BASE_TABLE_NAME || "schematical_agent_demo-knowledge-base",
    region: process.env.AWS_REGION || "us-east-1",
    limit: null,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case "--feed-url":
        args.feedUrl = argv[++i];
        break;
      case "--table-name":
        args.tableName = argv[++i];
        break;
      case "--region":
        args.region = argv[++i];
        break;
      case "--limit":
        args.limit = parseInt(argv[++i], 10);
        break;
      case "--dry-run":
        args.dryRun = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log(`Fetching ${args.feedUrl} ...`);
  const feedText = await fetchFeed(args.feedUrl);

  let items = parseItems(feedText);
  if (args.limit !== null) {
    items = items.slice(0, args.limit);
  }

  console.log(`Parsed ${items.length} post(s) from feed.`);

  if (args.dryRun) {
    for (const item of items) {
      console.log(
        `  [dry-run] ${item.id} - ${JSON.stringify(item.title)} (${item.text.length} chars, category=${item.category})`
      );
    }
    return;
  }

  const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
  const client = new DynamoDBClient({ region: args.region });

  let written = 0;
  let skipped = 0;
  for (const item of items) {
    try {
      await client.send(
        new PutItemCommand({
          TableName: args.tableName,
          Item: {
            id: { S: item.id },
            title: { S: item.title },
            text: { S: item.text },
            category: { S: item.category },
          },
        })
      );
      written += 1;
      console.log(`  wrote ${item.id}`);
    } catch (e) {
      skipped += 1;
      console.error(`  ERROR writing ${item.id}: ${e.message}`);
    }
  }

  console.log(`Done. ${written} written, ${skipped} skipped.`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
