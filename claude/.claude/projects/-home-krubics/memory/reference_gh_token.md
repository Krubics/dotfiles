---
name: gh-token-path
description: Path to the GitHub personal access token file used with GH_TOKEN env var
metadata: 
  node_type: memory
  type: reference
  originSessionId: a4ecef74-ced2-4518-baaf-e35fb28e9607
  modified: 2026-07-24T16:43:25.692Z
---

GitHub PAT is stored at `/home/krubics/.local/share/gh-token` (dash, not underscore).

Usage: `GH_TOKEN="$(cat ~/.local/share/gh-token)" gh <command>`

The system keyring (kwallet) is not available on this Hyprland setup, so gh cannot use its normal auth flow. Always use GH_TOKEN explicitly in commands or ensure it's exported in the shell session via `.zshrc`.
