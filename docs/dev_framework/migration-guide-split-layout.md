# Migration guide: flat layout → split layout

The canonical framework layout is **split**: Claude Code is invoked from a parent directory that holds tracking material (`CLAUDE.md`, `docs/`, `.claude/`), with the git repo living as a named subdirectory. If your project currently invokes Claude Code from inside the git repo itself (flat layout), this guide walks the migration.

See [ADR-019](../architecture/adr-019-split-layout.md) for the rationale.

---

## What you're doing

Before:
```
my-project/          ← Claude invoked from here; also the git root
  CLAUDE.md
  .claude/
  docs/
  src/
  .git/
  .env
```

After:
```
my-project/          ← Claude invoked from here (tracking tree)
  CLAUDE.md
  .claude/
  docs/
  references/
  .env               ← parent .env; see step 4
  my-repo-slug/      ← git root; name matches GitHub repo slug
    src/
    .git/
    .env             ← code-level secrets (optional; see step 4)
```

---

## Steps

### 1. Create the parent directory

```bash
# Move up one level — the current project dir becomes the code subdir
cd ..
mkdir my-project-parent
mv my-project my-project-parent/my-repo-slug
cd my-project-parent
```

Replace `my-repo-slug` with your GitHub repo's slug (the repository name, not the org).

### 2. Move tracking material to the parent

```bash
# From inside my-project-parent:
mv my-repo-slug/CLAUDE.md .
mv my-repo-slug/.claude .
mv my-repo-slug/.mcp.json .           # if present
mv my-repo-slug/docs .
mv my-repo-slug/references .         # if present
```

Leave all code files (`src/`, `tests/`, `package.json`, `Makefile`, etc.) inside `my-repo-slug/`.

### 3. Update .gitignore (if present)

Your code repo's `.gitignore` may have entries for `docs/` or `.claude/`. Since those now live at the parent level, they're outside the git repo and no longer need to be ignored. Review and clean up if needed.

### 4. Set up .env

Create `$PROJECT_DIR/.env` (at the parent level) with at minimum:

```bash
# Points to the canonical template repo for framework sync
CLAUDE_TEMPLATE_ROOT=/path/to/claude_template

# The name of the code subdirectory (matches GitHub repo slug)
DEFAULT_CODE_SUBDIR=my-repo-slug
```

If your code repo has its own `.env` for runtime secrets (database URLs, API keys, etc.), you have two options:

- **Separate files (recommended):** parent `.env` holds only framework vars; code repo `.env` holds runtime secrets. Both exist independently.
- **Symlink bridge:** `ln -s my-repo-slug/.env .env` at the parent, so a single `.env` serves both. The sync hook resolves `CLAUDE_TEMPLATE_ROOT` from either location automatically as of this ADR.

### 5. Update CLAUDE.md for the new layout

At the top of `CLAUDE.md`, fill in:
```
**Repository layout:** split — code at `my-repo-slug/`
```

And update `{{ports}}` and other template variables if you haven't already.

### 6. Invoke Claude from the parent

From now on, always `cd` to `$PROJECT_DIR` (the parent) before starting Claude Code:

```bash
cd my-project-parent
set -a; source .env; set +a
claude
```

If you use a shell alias or `.envrc`, update it to point at the parent.

### 7. Verify

Start a session. The `[sync-framework]` output should no longer show the flat-layout warning. You should see:

```
[sync-framework] docs/dev_framework/ synced from template
[sync-framework] .claude/hooks/ synced from template (additive; ...)
[sync-framework] CLAUDE.md managed block refreshed from template
[sync-framework] done.
```

No `NOTICE: flat layout detected` line = migration complete.

---

## Multi-repo projects

If one parent holds N code repos, add entries in `.env` for each after the migration:

```bash
DEFAULT_CODE_SUBDIR=api        # primary repo (used when W-item has no Target-repo:)
```

In your plan's W-item files, add the optional field for non-default repos:

```
Target-repo: web
```

The Orchestrator and Developer resolve `$CODE_ROOT = $PROJECT_DIR/$TARGET_REPO` from this field.

---

## Checklist

- [ ] Parent directory created; code repo is a subdirectory named after the GitHub slug
- [ ] CLAUDE.md, .claude/, docs/, .mcp.json, references/ are at parent level
- [ ] `$PROJECT_DIR/.env` has `DEFAULT_CODE_SUBDIR` and `CLAUDE_TEMPLATE_ROOT`
- [ ] Claude Code is invoked from `$PROJECT_DIR`, not from inside the code repo
- [ ] Session-start sync runs without the flat-layout warning
