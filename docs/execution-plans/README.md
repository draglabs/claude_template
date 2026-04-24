# Execution plans

This directory holds the work plans that the Orchestrator executes against. Each plan is a self-contained document covering one phase or initiative.

## Naming convention

`exec-<slug>.md` for active plans.

## Archival

When a plan is complete:
1. Add `## Status: CLOSED` header.
2. Move the file to `docs/archive/`.
3. Remove from CLAUDE.md's reading order.
4. Add a one-line summary to `docs/archive/README.md`.

**Closed plans are never in the session-start reading list.** This is how context stays manageable — see `docs/dev_framework/context-management.md`.

## Plan size limit

A single plan should stay under **150 lines / 15 W-items**. Larger initiatives should be split into focused sub-plans by stream or theme. This keeps each plan readable within a session's context budget.

## W-item structure

Each work item in a plan should have:

```markdown
### W-A1 — Short title

**Effort:** S | **Markers:** ⚠️ | **Status:** pending

**What:** One sentence describing what this item produces.

**Acceptance criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

**Touches:** `src/foo.ts`, `src/bar.ts`

**References:** `src/legacy/foo.py:120-280` (auth middleware pattern) — optional; read-only orientation material for the Executor (typical on port / migration / refactor W-items). Omit when the Touches list is enough.

**Depends on:** W-A0 (if any)

**Parallel-safe:** true | false — see §"Parallel-safe field" below. Default when unset: false.

**Branch:** — (populated when status becomes in_progress)
**Notes:** — (populated on stumped, ship-with-concerns, or — when Parallel-safe is true — the Strategist's "considered factors" line)
```

## Fields

| Field | Purpose |
|-------|---------|
| **W-id** | Unique within the plan. Format: `W-<stream><number>` (e.g. W-A1, W-B3). Streams group related items. |
| **Effort** | XS / S / M / L / XL — drives the tiered execution pattern in session-policy.md. |
| **Markers** | ⚠️ = architectural/irreversible (forces QA + bumps the Orchestrator's retry cap to 3; Opus review and worktree are already the default). 🔍 = spike/research (Orchestrator runs directly, 2h max — no Executor dispatch). 🔍 ALSO applies to branch-topology work that cannot run inside a worktree (resetting dev, cleaning orphan branches, gitignore fixes on long-lived branches) — these run on the Orchestrator's main working tree, not a feature worktree. Combine with ⚠️ when the operation is destructive (force-push, branch deletion). 🧪 = requires live QA verification regardless of tier. |
| **Status** | One of `pending` / `in_progress` / `blocked` / `done` / `shipped`. Owned by the Orchestrator — updated atomically with each dispatch / merge / stumped / phase-exit event. See state machine below. |
| **What** | One sentence. What artifact does this item produce? |
| **Acceptance** | Checkboxes. All must be green before the item is done. |
| **Touches** | Files the item will modify. Executor subagents use this as their scope boundary. |
| **References** | Optional. Read-for-orientation files with optional line ranges (e.g. `src/legacy/foo.py:120-280`). Intended for port / migration / refactor work where pre-existing structure must be understood before writing. Populated by the Strategist, often from a Code Consultant scout. Files here are read-only — modifying one is scope creep. Omit the field when the Touches list alone is enough context. |
| **Depends on** | Other W-ids that must be complete first. Forms the dependency graph. |
| **Parallel-safe** | `true` = eligible for batch-mode dispatch with concurrent peers (see ADR-016). `false` = dispatch under the per-task peer chain (ADR-013). Owned by the Strategist; set at plan time. Default when unset: `false`. See §"Parallel-safe field" below for the judgment rule. |
| **Branch** | `w-<id>/<slug>` — populated when status becomes `in_progress`. Lets any session see at a glance which branch the work lives on. |
| **Notes** | Terse log of non-obvious events: stumped reason + resolution, ship-with-concerns text, Lessons Learned highlights worth keeping past the merge commit. Not a diary — one line per event max. For `Parallel-safe: true` items, Notes MUST open with a "Parallel-safe considered: <factors>" line naming the shared surfaces the Strategist evaluated (package.json, lockfile, migrations, schema, route registry, shared test fixtures, refactor-of-a-callee) before declaring the item safe. |

## Parallel-safe field

The `Parallel-safe` field gates batch-mode dispatch (ADR-016). When `true`, the Orchestrator may dispatch the item concurrently with other `Parallel-safe: true` items in a batch of up to ~3, with one Integrator-QA (Opus 1M) call replacing the per-task Reviewer and per-W-item (pre-merge) QA. When `false` (or unset), the item flows through the per-task peer chain from ADR-013: Executor → Reviewer → optional QA → merge.

**Judgment rule (Strategist-owned).** `Parallel-safe: true` requires the W-item to be independent of every other W-item in the same plan at the level of **every shared runtime and build surface**, not just `Touches`. Two items with disjoint `Touches` can still conflict on:

- `package.json` / lockfile changes
- Shared configuration (env schema, route registry, feature flag registry)
- Database migration ordering
- Schema changes that other items consume
- Refactor of a callee that other items call
- Shared test fixtures or test-DB seed
- Dev-environment setup (dev-server port, docker-compose service names)

The framework does NOT auto-derive `Parallel-safe` from `Touches`. The Strategist considers the shared surfaces above and decides explicitly. Whenever `Parallel-safe` is set to `true`, the Notes field MUST include a `"Parallel-safe considered: <factors>"` line naming what was evaluated — this forces the judgment to be recorded rather than mechanized.

**Default when unset:** `false`. Adopter plans that predate ADR-016 (no `Parallel-safe` field on any W-item) continue to flow through the per-task peer chain. Strategists backfill the field when they decide to opt items into batch mode. No plan breaks at sync time.

## Status state machine

```
      ┌─────────┐
      │ pending │ ← default for newly-added W-items
      └────┬────┘
           │ Orchestrator dispatches Executor
           ▼
    ┌─────────────┐      Executor returns stumped      ┌─────────┐
    │ in_progress │ ────────────────────────────────▶ │ blocked │
    └──────┬──────┘                                    └────┬────┘
           │ Executor returns pass;                          │ Orchestrator
           │ Orchestrator merges to dev                      │ dispatches new
           ▼                                                 │ sharpened brief
      ┌──────┐                                               │ (back to
      │ done │ ◀─────────────────────────────────────────────┘ in_progress)
      └───┬──┘
          │ Phase exit QA passes; user authorizes;
          │ Orchestrator merges dev → main
          ▼
     ┌─────────┐
     │ shipped │ ← terminal
     └─────────┘
```

### Transition rules (all owned by Orchestrator)

| From → To | Trigger | Required action |
|---|---|---|
| `pending` → `in_progress` | Orchestrator about to spawn Executor | Edit plan: set Status, populate Branch. Commit plan update to `dev` BEFORE spawning the Executor. |
| `in_progress` → `done` | Executor returned pass + Orchestrator merged feature → `dev` | Edit plan: set Status to `done`. Commit plan update as part of / alongside the merge commit. |
| `in_progress` → `blocked` | Executor returned stumped | Edit plan: set Status, add Notes line with the unresolved concern. Commit plan update. Do NOT dispatch another Executor until the blocker is addressed. |
| `blocked` → `in_progress` | Orchestrator dispatches a new Executor with a sharpened brief (or user/Strategist resolves the blocker) | Edit plan: set Status back to `in_progress`, update Branch if different. Commit plan update before re-spawning. |
| `done` → `shipped` | Phase exit QA passes + user authorizes promotion + Orchestrator merges `dev` → `main` | Edit plan: set Status to `shipped` for every W-item in the promoted phase. Commit plan update alongside the promotion merge. |

Any transition the Orchestrator performs happens in the same commit group as the git event that triggered it. The plan is a ledger — stale entries mean the ledger is lying and a future session will dispatch duplicate work or skip done work.

### Reconciliation (on session start)

A fresh Orchestrator session MUST reconcile the plan ledger against git reality before dispatching anything. See `orchestrator-bootstrap.md` STEP 0. If the ledger and git disagree, the Orchestrator reports to the user and does NOT auto-fix — the gap might represent lost work, abandoned branches, or a concurrent session.

## Summary table (top of plan)

Each plan should include a summary table at the top. The table includes Status so a session reading the plan top-down sees the state of every item without scrolling.

```markdown
| W-id | Title | Effort | Markers | Status | Depends on |
|------|-------|--------|---------|--------|------------|
| W-A1 | Auth alignment | S | ⚠️ | done | — |
| W-A2 | Task claim | M | ⚠️ | in_progress | W-A1 |
| W-A3 | Webhook retry | S | — | pending | W-A2 |
```

The Orchestrator reads this table to decide execution order and tier-appropriate handling. Status columns here MUST match the per-W-item Status field — when the Orchestrator updates one, it updates both in the same commit.

## Integration claims

**Filed by the Integrator-QA in batch mode (ADR-016) when a fix would require stepping outside a W-item's acceptance criteria.** The Integrator does NOT change scope unilaterally. Instead, when its confidence in a proposed scope change is ≥80%, it files an integration claim inline on the active plan. The Strategist triages with the user. When confidence is <80%, the Integrator surfaces to the user immediately as a feature integration failure; no claim is filed.

### Where claims live

Integration claims live inline on the same plan file the W-items live on. Two sections at the bottom of the plan:

```markdown
## Integration claims (open)

(Open claims — held W-items do not merge until the Strategist + user dispose.)

### IC-NNN — YYYY-MM-DD — {{W-id(s)}} — {{short title}}

**Filed by:** Integrator-QA, batch <ids>
**Confidence:** <pct>
**Proposed scope change:** <what Integrator wants to do but won't do unilaterally>
**Why:** <what forced the proposal — test failing for X, acceptance ambiguous on Y>
**Blocks:** <W-item ids whose merge is held pending resolution>

## Integration claims (resolved)

### IC-NNN — YYYY-MM-DD → resolved YYYY-MM-DD — {{title}}

**Disposition:** approve | reject | modify
**Resolution:** <one-line summary of what the Strategist + user decided>
**Follow-up:** <W-item id if the resolution opened a new item, or "none">
```

### Numbering

Sequential across the plan, `IC-001`, `IC-002`, etc. Numbers persist across open → resolved. The Integrator-QA assigns the next unused number when filing.

### Blocking semantics

An open claim blocks **only the named W-items** from merging. Other W-items in the same batch that aren't named proceed through merge normally. Other batches, sequential work, and Orchestrator forward progress are not blocked. If the Strategist's resolution modifies acceptance or opens a follow-up W-item, the named W-items either re-enter dispatch (with the updated acceptance) or stay blocked pending the follow-up — the Strategist records which in the claim's Resolution line.

### Triage

The Strategist reviews open claims at phase boundaries and on demand, in the same triage pass as `process-exceptions.md`. Dispositions:

- **approve** — Integrator's proposed change is sound. Strategist updates the W-item's acceptance / plan, and the Integrator re-runs its fix pass on the affected items.
- **reject** — Do not make the change. The Integrator-QA surfaces a revised plan (or a stumped return) instead.
- **modify** — Strategist revises the proposal before approval, then the Integrator re-runs.

Every disposition is recorded in the Resolved section. Never delete — the history is the value.

### When a claim is NOT appropriate

- **Ordinary bugs within acceptance.** The Integrator fixes those inline; no claim.
- **Standards violations** (hardcoded values, missing tests, silent fallbacks) within acceptance. Same — the Integrator writes a fix commit per `coding-standards.md`.
- **Confidence <80%.** Surface to the user directly; don't hand them a low-confidence proposal to chew on.
- **Issues the Integrator caught in its first-pass high-profile scan.** Those are surfaced immediately as feature integration failures, not claims — the distinction is that the first-pass scan catches problems that should halt the batch before deep work, whereas claims emerge from deep work that revealed an acceptance ambiguity.
