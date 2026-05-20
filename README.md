# claude_template

A multi-agent Claude Code framework for software projects. Provides a role-based SOP (Strategist, Designer, Orchestrator, Developer, Template Developer) with peer-dispatch subagents, framework sync on session start, and a branch model that gates production deploys through CI.

## What it is

This repo is the **canonical template** — it ships via `sync-framework.sh` into adopter repos on every session start. You don't use this repo directly to build a product; you fork the structure, fill in the stub variables, and adopt the framework.

## Project layout

The canonical layout is **split**: Claude Code is invoked from a parent directory that holds tracking material (`CLAUDE.md`, `docs/`, `.claude/`), with the git repo as a named subdirectory:

```
$PROJECT_DIR/
  CLAUDE.md
  .claude/
  docs/
  .env              ← DEFAULT_CODE_SUBDIR=<repo-slug>, CLAUDE_TEMPLATE_ROOT=...
  <repo-slug>/      ← git root; name matches GitHub repo slug
    src/
    .git/
```

Multi-repo projects (one parent, N code repos) are supported: set `DEFAULT_CODE_SUBDIR` in `.env` for the primary repo and add `Target-repo: <subdir>` to W-items that target non-default repos.

If your project currently uses flat layout (project dir == git root), see `docs/dev_framework/migration-guide-split-layout.md`.

## Quick start

1. Create your project's parent directory.
2. Clone your code repo as a subdirectory named after your GitHub slug.
3. Copy `CLAUDE.md`, `.claude/`, `docs/`, and `.mcp.json` from this template to the parent.
4. Create `$PROJECT_DIR/.env` with `DEFAULT_CODE_SUBDIR` and `CLAUDE_TEMPLATE_ROOT`.
5. Invoke Claude Code from the parent: `cd $PROJECT_DIR && claude`.
6. Declare a role to bootstrap: `"you are the Strategist"`.

## Key docs

| Doc | Purpose |
|---|---|
| `CLAUDE.md` | Layer 0 — every session reads this |
| `docs/dev_framework/dev_framework.md` | SOP overview and agent stack |
| `docs/dev_framework/context-management.md` | Layered context loading + `$CODE_ROOT` |
| `docs/dev_framework/migration-guide-split-layout.md` | Migrate flat → split layout |
| `docs/architecture/adr-019-split-layout.md` | Layout convention decision record |

## Framework sync

`sync-framework.sh` runs on every session start and destructively overwrites `docs/dev_framework/` and `.claude/hooks/` in the adopter repo from this template. Adopters make project-specific deviations ONLY in `docs/framework_exceptions/dev_framework_exceptions.md` — never in `docs/dev_framework/`.
