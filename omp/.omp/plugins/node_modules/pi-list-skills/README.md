# pi-list-skills

A [Pi](https://pi.dev) extension that lists all loaded skills grouped by source.

## Features

- **`/list-skills` command** — interactive select UI showing skills grouped by where they came from
- **`list_skills` tool** — LLM-callable tool that returns skills as structured markdown, grouped by source
- **Source grouping** — skills are automatically organized by origin:
  - Git repos (e.g., `github.com/user/pi-skills`)
  - npm packages (e.g., `npm:pi-skill-package`)
  - Global skills (`~/.pi/agent/skills`, `~/.agents/skills`)
  - Project skills (`.pi/skills`, `.agents/skills`)

## Install

```bash
pi install npm:pi-list-skills
```

Then `/reload` in Pi or restart.

## Usage

```
/list-skills          # interactive select UI, grouped by source
```

Or ask the agent: "what skills are loaded?"

## Example output

### `/list-skills` command (interactive select UI)

```
Loaded Skills (5)

── github.com/example/pi-skills ──
  example-skill  —  An example skill from a git repository.
  another-skill  —  Another example skill from a git repository.

── npm:pi-example-package ──
  packaged-skill  —  An example skill installed via npm.

── Global (~/.pi/agent/skills) ──
  global-skill  —  An example globally-installed skill.

── Project (.pi/skills) ──
  project-skill  —  An example project-level skill.
```

Selecting a skill shows its name, description, and file location.

### `list_skills` tool (LLM-callable, returns markdown)

```
## Loaded Skills (5)

### github.com/example/pi-skills

- **example-skill** — An example skill from a git repository.
- **another-skill** — Another example skill from a git repository.

### npm:pi-example-package

- **packaged-skill** — An example skill installed via npm.

### Global (~/.pi/agent/skills)

- **global-skill** — An example globally-installed skill.

### Project (.pi/skills)

- **project-skill** — An example project-level skill.
```

## License

MIT
