import os
from datetime import datetime, timezone
from typing import List

from strands.types.tools import AgentTool
from strands_tools.agent_core_memory import AgentCoreMemoryToolProvider
from bedrock_agentcore.memory import MemoryClient

MEMORY_ID = os.getenv("MEMORY_ID")
MEMORY_STRATEGY_ID = os.getenv("MEMORY_STRATEGY_ID")
AWS_REGION = os.getenv("AWS_REGION")

# Used only when the caller doesn't give us a real actor/session (e.g. no
# RequestContext.session_id, no custom actor-id header).
DEFAULT_ACTOR_ID = "user123"
DEFAULT_SESSION_ID = "session456"


def build_memory_tools(actor_id: str, session_id: str) -> List[AgentTool]:
    """Build long-term memory tools (record/retrieve/list/get/delete) scoped to one request.

    Each invocation gets its own AgentCoreMemoryToolProvider instance, so
    actor_id/session_id live on that instance rather than in shared module
    state - safe under concurrent invocations.
    """
    provider = AgentCoreMemoryToolProvider(
        memory_id=MEMORY_ID,
        actor_id=actor_id,
        session_id=session_id,
        namespace=f"/strategies/{MEMORY_STRATEGY_ID}/actors/{actor_id}",
        region=AWS_REGION,
    )
    return provider.tools


def log_conversation_turn(actor_id: str, session_id: str, user_message: str, assistant_message: str) -> None:
    """Record a user/assistant turn as a short-term memory event.

    Long-term memories are extracted from these events asynchronously by
    whatever strategies are configured on the Memory resource (see the
    SEMANTIC strategy in agentcore_memory.tf) - this call itself only writes
    to short-term memory.
    """
    try:
        client = MemoryClient(region_name=AWS_REGION)
        client.create_event(
            memory_id=MEMORY_ID,
            actor_id=actor_id,
            session_id=session_id,
            messages=[(user_message, "USER"), (assistant_message, "ASSISTANT")],
            event_timestamp=datetime.now(timezone.utc),
        )
    except Exception as e:
        print(f"Error logging conversation turn to memory: {e}")
