---
name: feedback_no_redundant_reads
description: Do not re-read a file when its content is already known from a prior Read in the same session
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8c740eb5-c48d-4f00-aa80-ed27a4c59150
---

Do not re-read a file when the content is already current in context from a prior Read or Edit tool result.

**Why:** Wastes a tool call and adds noise. The user called this out explicitly: "Wasted call — file unchanged since your last Read. Refer to that earlier tool_result instead."

**How to apply:** After a successful Read or Edit, treat the content as authoritative for the rest of the turn. Only re-read if the user indicates the file changed externally, or if significant time/turns have passed and the state is genuinely uncertain.
