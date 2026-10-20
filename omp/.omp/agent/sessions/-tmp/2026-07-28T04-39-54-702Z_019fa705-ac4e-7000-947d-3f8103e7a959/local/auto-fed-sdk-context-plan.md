# Auto-Fed SDK Context — Research-Only

## Context
The user asked what context, tools, hooks, etc. are automatically fed to the Claude SDK without explicit specification. This was an informational/research question, not an implementation request. The grounded answer (Anthropic SDK vs Claude Agent SDK; what `settingSources` loads by default; what is read regardless of `settingSources`; built-in tools; hooks; permissions; MCP) has been delivered in the conversation.

## Approach
No implementation steps. No files to create, edit, or delete. The deliverable is the research answer already provided, sourced from the official Agent SDK and Claude Code settings documentation.

## Verification
None required — no behavior was changed. The answer is grounded in:
- https://code.claude.com/docs/en/agent-sdk
- https://code.claude.com/docs/en/agent-sdk/claude-code-features
- https://code.claude.com/docs/en/settings

## Assumptions & contingencies
- Assumption: the user meant the **Claude Agent SDK** (the only Anthropic SDK with hooks/auto-context), not the raw `anthropic` Messages API SDK, which has none of these auto-fed features. The user confirmed via `ask` that no implementation work is needed.
- If the user later wants an implementation (e.g., a clean/isolated SDK config, or a full project-context setup), that becomes a separate planning request.
