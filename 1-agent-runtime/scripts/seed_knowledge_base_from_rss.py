#!/usr/bin/env python3
"""One-time utility to seed the knowledge base DynamoDB table from the
schematical.com RSS feed. Not part of the deployed agent container - run
manually from a machine with AWS credentials and boto3 installed:

    python3 scripts/seed_knowledge_base_from_rss.py [--dry-run] [--limit N]

Writes id/title/text/category only. The `embedding` attribute is
intentionally left unset - the DynamoDB Streams -> Lambda pipeline
(lambda/vectorize/handler.py) fills it in asynchronously after each item
lands in the table. Re-running is safe: ids are derived from each post's
URL slug, so put_item overwrites rather than duplicates.
"""

import argparse
import hashlib
import html
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from urllib.parse import urlparse

FEED_URL = "https://schematical.com/api/posts.rss"
CONTENT_NS = {"content": "http://purl.org/rss/1.0/modules/content/"}
DEFAULT_CATEGORY = "main"

TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"\s+")


def strip_html(raw_html: str) -> str:
    text = TAG_RE.sub(" ", raw_html)
    text = html.unescape(text)
    return WHITESPACE_RE.sub(" ", text).strip()


def slug_from_link(link: str) -> str:
    path = urlparse(link).path.rstrip("/")
    slug = path.rsplit("/", 1)[-1]
    if not slug:
        slug = hashlib.sha256(link.encode("utf-8")).hexdigest()[:16]
    return slug


def fetch_feed(feed_url: str) -> bytes:
    request = urllib.request.Request(feed_url, headers={"User-Agent": "seed-knowledge-base/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def parse_items(feed_bytes: bytes):
    root = ET.fromstring(feed_bytes)
    for item in root.findall("./channel/item"):
        title_el = item.find("title")
        link_el = item.find("link")
        content_el = item.find("content:encoded", CONTENT_NS)
        description_el = item.find("description")
        category_el = item.find("category")

        link = (link_el.text or "").strip() if link_el is not None else ""
        title = (title_el.text or "").strip() if title_el is not None else ""

        body_html = ""
        if content_el is not None and content_el.text:
            body_html = content_el.text
        elif description_el is not None and description_el.text:
            body_html = description_el.text

        text = strip_html(body_html)
        category = (category_el.text or "").strip() if category_el is not None else DEFAULT_CATEGORY

        if not link or not title or not text:
            continue

        yield {
            "id": slug_from_link(link),
            "title": title,
            "text": text,
            "category": category or DEFAULT_CATEGORY,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feed-url", default=FEED_URL)
    parser.add_argument("--table-name", default=os.getenv("KNOWLEDGE_BASE_TABLE_NAME", "schematical_agent_demo-knowledge-base"))
    parser.add_argument("--region", default=os.getenv("AWS_REGION", "us-east-1"))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true", help="Parse and print without writing to DynamoDB")
    args = parser.parse_args()

    if not args.dry_run and not args.table_name:
        parser.error("--table-name is required (or set KNOWLEDGE_BASE_TABLE_NAME) unless --dry-run")

    print(f"Fetching {args.feed_url} ...")
    feed_bytes = fetch_feed(args.feed_url)

    items = list(parse_items(feed_bytes))
    if args.limit is not None:
        items = items[: args.limit]

    print(f"Parsed {len(items)} post(s) from feed.")

    if args.dry_run:
        for item in items:
            print(f"  [dry-run] {item['id']} - {item['title']!r} ({len(item['text'])} chars, category={item['category']})")
        return

    import boto3

    table = boto3.resource("dynamodb", region_name=args.region).Table(args.table_name)

    written = 0
    skipped = 0
    for item in items:
        try:
            table.put_item(Item=item)
            written += 1
            print(f"  wrote {item['id']}")
        except Exception as e:
            skipped += 1
            print(f"  ERROR writing {item['id']}: {e}", file=sys.stderr)

    print(f"Done. {written} written, {skipped} skipped.")


if __name__ == "__main__":
    main()
