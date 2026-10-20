---
name: prefers-standard-tools-over-custom-scripts
description: "User pushes back on bespoke solutions — wants simpler/standard tools surfaced first, and reusable code"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 02f177ba-37c8-45c7-bf6b-221b9f47284e
---

When given a working solution, the user repeatedly probes for simpler alternatives before accepting it. In the stub-generation work they asked, in order: "could there have been a simpler way to do this?", "is there a library out there that solves this without a custom script?", and "is the custom script reusable across projects or coupled to this library?".

**Why:** They prefer off-the-shelf / standard tooling over custom code, value an honest assessment of whether a simpler path existed (even after the fact), and care about portability/reuse rather than one-off scripts.

**How to apply:** Before proposing a custom script, surface (a) whether an existing library/tool already does it, and (b) the minimal version of the fix. When a custom script is genuinely needed, make it parameterized/portable from the start and say plainly where the simpler boundary was. Don't over-engineer or expand scope without flagging it.
