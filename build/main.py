from strands import Agent
from bedrock_agentcore.runtime import BedrockAgentCoreApp, RequestContext
from rich.console import Console

from tools.browser import get_latest_schematical_posts
from tools.memory import build_memory_tools, log_conversation_turn, DEFAULT_ACTOR_ID, DEFAULT_SESSION_ID

app = BedrockAgentCoreApp()
console = Console()

ACTOR_ID_HEADER = "x-amzn-bedrock-agentcore-runtime-custom-actor-id"


def create_agent(actor_id: str, session_id: str) -> Agent:
    """Create a basic agent with simple functionality"""
    system_prompt = """You are a helpful assistant. Answer questions clearly and concisely."""

    return Agent(
        tools=[
            get_latest_schematical_posts,
            *build_memory_tools(actor_id, session_id),
        ],
        system_prompt=system_prompt,
        name="BasicAgent"
    )


@app.entrypoint
async def invoke(payload=None, context: RequestContext = None):
    """Main entrypoint for the agent"""
    try:
        console.print(f"[blue]🤖 invoke task:[/blue] {payload.get('prompt', 'Hello, how are you?')[:100]}...")
        # Get the query from payload
        query = payload.get("prompt", "Hello, how are you?") if payload else "Hello, how are you?"

        # AgentCore Runtime manages session_id itself; actor_id comes from a
        # custom header if the caller sets one. Fall back to the static
        # defaults when either isn't available.
        actor_id = DEFAULT_ACTOR_ID
        if context and context.request_headers:
            actor_id = context.request_headers.get(ACTOR_ID_HEADER, DEFAULT_ACTOR_ID)
        session_id = (context.session_id if context else None) or DEFAULT_SESSION_ID

        # Create and use the agent
        agent = create_agent(actor_id, session_id)
        response = agent(query)
        response_text = response.message["content"][0]["text"]

        log_conversation_turn(actor_id, session_id, query, response_text)

        return {"status": "success", "response": response_text}

    except Exception as e:
        return {"status": "error", "error": str(e), "stack": e.__traceback__}


if __name__ == "__main__":
    app.run()
