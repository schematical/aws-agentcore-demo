resource "aws_bedrockagentcore_memory" "agentcore_memory" {
  name                  = "${replace(var.project_name, "-", "_")}"
  description           = "Memory for ${var.project_name} "
  event_expiry_duration = 30 # Days
}

# Without a strategy, events written via create_event stay as short-term
# memory only - nothing ever gets extracted into long-term memory records
# for retrieve_memories to find.
resource "aws_bedrockagentcore_memory_strategy" "semantic" {
  name                = "${replace(var.project_name, "-", "_")}_semantic"
  memory_id           = aws_bedrockagentcore_memory.agentcore_memory.id
  type                = "SEMANTIC"
  description         = "Long-term semantic memory (facts, preferences) for ${var.project_name}"
  namespace_templates = ["/strategies/{memoryStrategyId}/actors/{actorId}"]
}