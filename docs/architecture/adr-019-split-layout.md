# ADR-019 — Split project layout as canonical convention

**Date:** 2026-05-20
**Status:** Accepted
**Authors:** Template Developer / David Strom

---

## Context

Every framework doc and hook has been written with the implicit assumption that the directory Claude Code is invoked from **is** the git repository. The two trees are the same tree.

Two independent pressures break that assumption:

1. **Ignoring docs in the code repo.** The `auto-jm-co` adopter's CTO issued a directive (EX-001, 2026-04-23) to gitignore all `*.md` files repo-wide. With framework docs, planning docs, and ADRs all untracked, keeping them inside the git repo was vestigial — a build artifact of how the template was originally structured, not a useful constraint.

2. **Multi-repo projects.** In practice, a single product spans multiple git repos (e.g., `api/`, `web/`, `infra/`). Claude Code is invoked once from a parent directory that holds shared tracking material, and each code repo is a subdirectory. The single-tree assumption makes this pattern awkward to express.

The solution that resolved both problems in practice: a **split layout** where the directory Claude Code is invoked from (`$PROJECT_DIR`) holds only tracking material, and the git repo(s) live as named subdirectories underneath it.

---

## Decision

**Split layout is the canonical project structure for the claude_template framework.**

Flat layout (where `$PROJECT_DIR` == git root) is legacy and will receive a soft migration warning from `sync-framework.sh` on every session start. The framework does not auto-migrate existing flat-layout adopters, but it provides a migration playbook (`docs/dev_framework/migration-guide-split-layout.md`) and does not support new features in flat-layout mode.

---

## Definitions

### Split layout (canonical)

```
$PROJECT_DIR/                 ← Claude Code is invoked from here
  CLAUDE.md
  .claude/
  .mcp.json
  .env                        ← holds CLAUDE_TEMPLATE_ROOT, DEFAULT_CODE_SUBDIR, etc.
  docs/                       ← planning, framework, ADRs
  references/                 ← external repo clones
  <repo-slug>/                ← git repo; name matches GitHub repo slug exactly
    src/
    tests/
    package.json
    .git/
    .env                      ← code-level secrets (symlinked or separate from parent .env)
    …
```

`$CODE_ROOT = $PROJECT_DIR/$CODE_SUBDIR`

### Multi-repo split layout

When one parent holds N code repos (single Claude Code session, shared tracking tree):

```
$PROJECT_DIR/
  CLAUDE.md
  .claude/
  docs/
  .env                        ← DEFAULT_CODE_SUBDIR=api (primary for single-repo ops)
  api/                        ← $PROJECT_DIR/api
    .git/
    …
  web/                        ← $PROJECT_DIR/web
    .git/
    …
  infra/                      ← $PROJECT_DIR/infra
    .git/
    …
```

Each W-item in the plan carries an optional `Target-repo: <subdir>` field.
`$CODE_ROOT = $PROJECT_DIR/$TARGET_REPO` for that W-item, defaulting to `$PROJECT_DIR/$DEFAULT_CODE_SUBDIR` when unset.

### Flat layout (legacy)

```
$PROJECT_DIR/                 ← also the git root
  CLAUDE.md
  .claude/
  docs/
  src/
  .git/
  …
```

`$CODE_ROOT == $PROJECT_DIR`

---

## `.env` convention for split layout

Minimum additions to `$PROJECT_DIR/.env`:

```bash
# Which subdirectory holds the code (matches GitHub repo slug)
DEFAULT_CODE_SUBDIR=my-repo-name

# Template location for framework sync
CLAUDE_TEMPLATE_ROOT=/path/to/claude_template
```

For multi-repo projects, `DEFAULT_CODE_SUBDIR` names the primary repo (used when a W-item does not specify `Target-repo:`).

---

## W-item field addition: `Target-repo`

For multi-repo projects, W-item files gain an optional metadata field:

```
Target-repo: <subdir>   # optional; defaults to DEFAULT_CODE_SUBDIR from .env
```

The Orchestrator and Developer resolve `$CODE_ROOT` from this field before creating worktrees or running git commands.

---

## Effect on sync-framework.sh

All sync targets in `sync-framework.sh` write to `$PROJECT_DIR` (the tracking tree), which is already correct for split layout:

| Hook step | Target path | Status |
|---|---|---|
| `docs/dev_framework/` sync | `$PROJECT_DIR/docs/dev_framework/` | ✓ already correct |
| `.claude/hooks/` sync | `$PROJECT_DIR/.claude/hooks/` | ✓ already correct |
| `docs/framework_exceptions/` init | `$PROJECT_DIR/docs/framework_exceptions/` | ✓ already correct |
| `.mcp.json` seed | `$PROJECT_DIR/.mcp.json` | ✓ already correct |
| `CLAUDE.md` managed-block refresh | `$PROJECT_DIR/CLAUDE.md` | ✓ already correct |

Two logic changes are added:

1. **`CLAUDE_TEMPLATE_ROOT` resolution fallback.** After trying `$PROJECT_DIR/.env`, the hook scans immediate subdirectories of `$PROJECT_DIR` that contain both `.git/` and `.env`, and tries those `.env` files for `CLAUDE_TEMPLATE_ROOT`. This removes the need for a symlink bridge in split-layout adopters who kept their single `.env` inside the code repo.

2. **Flat-layout detection warning.** If `$PROJECT_DIR/.git` exists, the hook emits a `NOTICE` prompting migration. Sync continues (soft warning, not a block).

---

## Effect on worktree paths

The Parallel Developer and Orchestrator-mode Executors use `/tmp/worktrees/<project>/w-<id>-<slug>`. Under this ADR, `<project>` is formally defined as the **git repository name** — `basename $CODE_ROOT` — not `basename $PROJECT_DIR`. In flat layout these are identical; in split layout they differ.

---

## Backward compatibility

Flat-layout adopters receive a session-start warning. All existing behavior is preserved. There is no forced migration, no data loss risk, and no auto-rewrite of their directory tree.

New adopters should use split layout from the start. The template stub, migration guide, and managed CLAUDE.md block all assume split layout.

---

## Named gaps (follow-up PR)

The following items are out of scope for this PR and are explicitly called out as gaps to prevent confusion:

### 1. `Target-repo:` mechanism in consumer docs

`Target-repo:` is defined here (W-item metadata field) and referenced in `developer.md` and `context-management.md`. It is **not yet wired into the consumer docs that must act on it**:

- `docs/dev_framework/templates/orchestrator-bootstrap.md` — STEP 1 worktree creation must resolve `$CODE_ROOT` from `Target-repo:` before `git worktree add`
- `docs/dev_framework/templates/executor-brief.md` — STEP 1 ("set working directory") must do the same

Until these docs are updated, `Target-repo:` is an English-only convention. Orchestrators and Executors using the template briefs will default to `DEFAULT_CODE_SUBDIR` regardless. Multi-repo projects must currently add a `dev_framework_exceptions.md` note overriding STEP 1 in those briefs.

### 2. `$CODE_ROOT` references in remaining framework files

The following docs have not been updated to reference `$CODE_ROOT` or the split-layout cd discipline. They retain implicit flat-layout assumptions in their path references and cd steps:

- `docs/dev_framework/coding-standards.md`
- `docs/dev_framework/strategist.md`
- `docs/dev_framework/templates/reviewer-brief.md`
- `docs/dev_framework/templates/integrator-qa-brief.md`

These files are not blockers for adopters working in split layout today — the cd discipline is defined in `developer.md §Working directory: $CODE_ROOT` and `context-management.md §Project layout`, and those are the primary references roles read. The above files will be updated in a follow-up pass once the split layout is validated across more adopters.

### 3. Plan-write commit semantics under split layout

When `$PROJECT_DIR` is not itself a git repo, plan edits at `$PROJECT_DIR/docs/execution-plans/...` cannot be git-committed as part of the code repo's `dev` branch. PLAN-WRITE DISCIPLINE's `git push origin dev` concurrent-claim safety model is weakened to filesystem-visibility only (edits are immediately visible on a shared filesystem, but the push-then-fail collision guard is unavailable). A follow-up PR will document whether `$PROJECT_DIR` should be a separate tracking git repo, or whether file-only plan writes are the sanctioned model for split layout.

---

## Related

- [ADR-014](adr-014-framework-sync-on-session-start.md) — sync hook design
- [ADR-015](adr-015-template-developer-role.md) — Template Developer role
- `docs/dev_framework/migration-guide-split-layout.md` — migration playbook
- `docs/dev_framework/context-management.md §Project layout` — runtime resolution rules
