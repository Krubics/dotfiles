/**
 * pi-list-skills — List all loaded skills grouped by source
 *
 * Registers:
 *   /list-skills  — interactive command that displays skills grouped by source
 *   list_skills   — tool the LLM can call to enumerate loaded skills
 *
 * Usage:
 *   pi install git:github.com:<user>/pi-list-skills
 *   # or copy to ~/.pi/agent/extensions/
 */

import { homedir } from "node:os";
import { join, relative, sep } from "node:path";
import type { ExtensionAPI, SlashCommandInfo } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ── Path parsing ───────────────────────────────────────────────────────

interface SkillEntry {
  name: string;
  description: string;
  path: string;
}

interface SkillGroup {
  label: string;
  skills: SkillEntry[];
}

/**
 * Classify a skill path into a human-readable source label.
 * Returns the group label and a short path for display.
 */
function classifyPath(absPath: string): { group: string; shortPath: string } {
  const home = homedir();
  const rel = absPath.startsWith(home) ? "~" + absPath.slice(home.length) : absPath;

  // Git-installed packages: ~/.pi/agent/git/github.com/user/repo/...
  const gitRoot = join(home, ".pi", "agent", "git");
  if (absPath.startsWith(gitRoot + sep)) {
    const rest = absPath.slice(gitRoot.length + 1);
    // rest looks like: github.com/user/repo/skills/name/SKILL.md
    const parts = rest.split(sep);
    if (parts.length >= 2) {
      const repo = parts.slice(0, 2).join("/"); // github.com/user
      const repoName = parts.length >= 3 ? parts.slice(0, 3).join("/") : repo; // github.com/user/repo
      return { group: repoName, shortPath: rel };
    }
  }

  // npm-installed packages: ~/.pi/agent/npm/...
  const npmRoot = join(home, ".pi", "agent", "npm");
  if (absPath.startsWith(npmRoot + sep)) {
    const rest = absPath.slice(npmRoot.length + 1);
    const pkgName = rest.split(sep)[0] ?? "npm";
    return { group: `npm:${pkgName}`, shortPath: rel };
  }

  // Global Pi skills: ~/.pi/agent/skills/...
  const piSkills = join(home, ".pi", "agent", "skills");
  if (absPath.startsWith(piSkills + sep)) {
    return { group: "Global (~/.pi/agent/skills)", shortPath: rel };
  }

  // Global agent skills: ~/.agents/skills/...
  const agentSkills = join(home, ".agents", "skills");
  if (absPath.startsWith(agentSkills + sep)) {
    return { group: "Global (~/.agents/skills)", shortPath: rel };
  }

  // Project-local skills
  if (absPath.includes(`${sep}.pi${sep}skills`)) {
    return { group: "Project (.pi/skills)", shortPath: rel };
  }
  if (absPath.includes(`${sep}.agents${sep}skills`)) {
    return { group: "Project (.agents/skills)", shortPath: rel };
  }

  return { group: "Other", shortPath: rel };
}

function buildGroups(
  skillCommands: Array<SlashCommandInfo & { source: "skill" }>,
  metaByName: Map<string, string>,
): SkillGroup[] {
  const groupMap = new Map<string, SkillEntry[]>();

  for (const cmd of skillCommands) {
    const desc = metaByName.get(cmd.name) ?? cmd.description ?? "(no description)";
    const path = cmd.sourceInfo?.path ?? "(unknown)";
    const { group } = classifyPath(path);

    const entry: SkillEntry = { name: cmd.name, description: desc, path };
    if (!groupMap.has(group)) groupMap.set(group, []);
    groupMap.get(group)!.push(entry);
  }

  // Sort groups: git repos first, then npm, then global, then project, then other
  const order: Record<string, number> = {
    git: 0,
    npm: 1,
    global: 2,
    project: 3,
    other: 4,
  };

  function groupPriority(label: string): number {
    if (label.includes("github.com") || label.includes("gitlab.com") || label.includes("bitbucket"))
      return order.git;
    if (label.startsWith("npm:")) return order.npm;
    if (label.startsWith("Global")) return order.global;
    if (label.startsWith("Project")) return order.project;
    return order.other;
  }

  return [...groupMap.entries()]
    .sort(([a], [b]) => {
      const pa = groupPriority(a);
      const pb = groupPriority(b);
      if (pa !== pb) return pa - pb;
      return a.localeCompare(b);
    })
    .map(([label, skills]) => {
      skills.sort((a, b) => a.name.localeCompare(b.name));
      return { label, skills };
    });
}

// ── Extension ──────────────────────────────────────────────────────────

export default function listSkillsExtension(pi: ExtensionAPI) {
  // ── /list-skills command ────────────────────────────────────────────
  pi.registerCommand("list-skills", {
    description: "List all loaded skills grouped by source",

    handler: async (_args, ctx) => {
      const allCommands = pi.getCommands();
      const skillCommands = allCommands.filter(
        (c): c is SlashCommandInfo & { source: "skill" } => c.source === "skill",
      );

      if (skillCommands.length === 0) {
        ctx.ui.notify("No skills loaded", "info");
        return;
      }

      // Richer metadata from system prompt options
      let skillMeta: Array<{ name: string; description: string }> = [];
      try {
        skillMeta = ctx.getSystemPromptOptions().skills ?? [];
      } catch {
        // unavailable in some contexts
      }
      const metaByName = new Map(skillMeta.map((s) => [s.name, s.description]));

      const groups = buildGroups(skillCommands, metaByName);
      const total = groups.reduce((sum, g) => sum + g.skills.length, 0);

      // Build select items with group headers
      const items: string[] = [];
      const flatList: SkillEntry[] = [];

      for (const group of groups) {
        items.push(`── ${group.label} ──`);
        for (const skill of group.skills) {
          const shortDesc =
            skill.description.length > 55
              ? skill.description.slice(0, 52) + "..."
              : skill.description;
          items.push(`  ${skill.name}  —  ${shortDesc}`);
          flatList.push(skill);
        }
      }

      const selected = await ctx.ui.select(`Loaded Skills (${total})`, items);

      if (selected && !selected.startsWith("──")) {
        const skillName = selected.trim().split("  —  ")[0];
        const skill = flatList.find((s) => s.name === skillName);
        if (skill) {
          const detail = [
            `Name: ${skill.name}`,
            `Description: ${skill.description}`,
            `Location: ${skill.path}`,
          ].join("\n");
          ctx.ui.notify(detail, "info");
        }
      }
    },
  });

  // ── list_skills tool ────────────────────────────────────────────────
  pi.registerTool({
    name: "list_skills",
    label: "List Skills",
    description:
      "List all loaded skills grouped by source (git repo, npm package, global, or project). Use when the user asks what skills are available.",
    parameters: Type.Object({}),

    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const allCommands = pi.getCommands();
      const skillCommands = allCommands.filter((c) => c.source === "skill");

      if (skillCommands.length === 0) {
        return {
          content: [{ type: "text", text: "No skills are currently loaded." }],
          details: { count: 0, groups: [] },
        };
      }

      const metaByName = new Map<string, string>();
      const groups = buildGroups(skillCommands, metaByName);
      const total = groups.reduce((sum, g) => sum + g.skills.length, 0);

      const lines: string[] = [`## Loaded Skills (${total})\n`];

      for (const group of groups) {
        lines.push(`### ${group.label}\n`);
        for (const skill of group.skills) {
          lines.push(`- **${skill.name}** — ${skill.description}`);
        }
        lines.push("");
      }

      return {
        content: [{ type: "text", text: lines.join("\n") }],
        details: {
          count: total,
          groups: groups.map((g) => ({
            source: g.label,
            skills: g.skills.map((s) => ({ name: s.name, description: s.description })),
          })),
        },
      };
    },
  });
}
