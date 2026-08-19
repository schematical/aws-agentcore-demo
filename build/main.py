from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from typing import Dict, Any
import json
import os
import asyncio
import traceback
from contextlib import suppress

from bedrock_agentcore.tools.browser_client import BrowserClient
from browser_use import Agent as BrowserAgent
from browser_use.browser.session import BrowseSession
from browser_use.browser import BrowserProfile
from langchain_aws import ChatBedrockConverse
from bedrock_agentcore.tools.code_interpreter_client import CodeInterpreter
from bedrock_agentcore.memory import MemoryClient
from rich.console import Console

app = BedrockAgentCoreApp()

console = Console()
BROWSER_ID = os.getenv("BROWSER_ID")
# CODE_INTERPRETER_ID = os.getenv("CODE_INTERPRETER_ID")
MEMORY_ID = os.getenv("MEMORY_ID")
AWS_REGION = os.getenv("AWS_REGION")

def create_agent() -> Agent:
    """Create a basic agent with simple functionality"""
    system_prompt = """You are a helpful assistant. Answer questions clearly and concisely."""

    return Agent(
        tools=[
            get_latest_schematical_posts
        ],
        system_prompt=system_prompt,
        name="BasicAgent"
    )

async def run_browser_task(browser_session, bedrock_chat, task: str) -> str:
    """Run a browser automation task using browser_use"""
    try:
        console.print(f"[blue]🤖 Executing browser task:[/blue] {task[:100]}...")

        agent = BrowserAgent(task=task, llm=bedrock_chat, browser=browser_session)

        result = await agent.run()
        console.print("[green]✅ Browser task completed successfully![/green]")

        if "done" in result.last_action() and "text" in result.last_action()["done"]:
            return result.last_action()["done"]["text"]
        else:
            raise ValueError("NO Data")

    except Exception as e:
        console.print(f"[red]❌ run_browser_task - Browser task error: {e}[/red]")
        traceback.print_exc()
        raise
async def initialize_browser_session():
    """Initialize Browser-use session with AgentCore WebSocket connection"""
    try:
        client = BrowserClient(AWS_REGION)
        client.start(identifier=BROWSER_ID)

        ws_url, headers = client.generate_ws_headers()
        console.print(f"[cyan]🔗 Browser WebSocket URL: {ws_url[:50]}...[/cyan]")

        browser_profile = BrowserProfile(
            headers=headers,
            timeout=150000,
        )

        browser_session = BrowserSession(cdp_url=ws_url, browser_profile=browser_profile, keep_alive=True)

        console.print("[cyan]🔄 Initializing browser session...[/cyan]")
        await browser_session.start()

        bedrock_chat = ChatBedrockConverse(
            model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0", # us.amazon.nova-2-lite-v1:0
            region_name=AWS_REGION,
        )

        console.print("[cyan]🧪 Testing direct Bedrock invoke (bypassing browser_use)...[/cyan]")
        try:
            test_response = await bedrock_chat.ainvoke("Reply with the word OK.")
            console.print(f"[green]✅ Direct Bedrock invoke succeeded: {test_response.content}[/green]")
        except Exception as bedrock_err:
            console.print(f"[red]❌ Direct Bedrock invoke failed: {type(bedrock_err).__name__}: {bedrock_err}[/red]")
            traceback.print_exc()
            raise

        console.print("[green]✅ Browser session initialized and ready[/green]")
        return browser_session, bedrock_chat, client

    except Exception as e:
        console.print(f"[red]❌ initialize_browser_session - Browser task error: {type(e).__name__}: {e}[/red]")
        traceback.print_exc()
        raise
# Tools for Strands Agent
@tool
async def get_latest_schematical_posts(keyword: str) -> Dict[str, Any]:

    browser_session = None

    try:
        console.print(f"[cyan]🌐 Getting webpagedata data for ")

        (
            browser_session,
            bedrock_chat,
            browser_client,
        ) = await initialize_browser_session()

        task = f"""Instruction: Summerize the latest schematical posts for 
            Steps:
                - Go to https://schematical.com/posts.
                - Wait for the  page to load completely.
                - Return a short summary of the posts with bullet points.
        """

        result = await run_browser_task(browser_session, bedrock_chat, task)

        if browser_client:
            browser_client.stop()

        return {"status": "success", "content": [{"text": result}]}

    except Exception as e:
        console.print(f"[red]❌ Error getting data: {e}[/red]")
        return {
            "status": "error",
            "content": [{"text": f"Error getting data: {str(e)}"}],
        }

    finally:
        if browser_session:
            console.print("[yellow]🔌 Closing browser session...[/yellow]")
            with suppress(Exception):
                await browser_session.close()
            console.print("[green]✅ Browser session closed[/green]")


@app.entrypoint
async def invoke(payload=None):
    """Main entrypoint for the agent"""
    try:
        console.print(f"[blue]🤖 invoke task:[/blue] {payload.get('prompt', 'Hello, how are you?')[:100]}...")
        # Get the query from payload
        query = payload.get("prompt", "Hello, how are you?") if payload else "Hello, how are you?"

        # Create and use the agent
        agent = create_agent()
        response = agent(query)

        return {"status": "success", "response": response.message["content"][0]["text"]}

    except Exception as e:
        return {"status": "error", "error": str(e), "stack": e.__traceback__}


if __name__ == "__main__":
    app.run()