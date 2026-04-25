# Execution plans

This directory holds the work plans the Orchestrator executes against. Each plan is a self-contained **folder** covering one phase or initiative.

## Plan structure

A plan is a folder under `docs/execution-plans/` containing three artifact types:

```
docs/execution-plans/
  README.md                # this file — framework spec
  exec-<slug>/             # one folder per active or archived plan
    plan.md                # the index — runtime state surface
    w-a1.md                # W-item SOW (one file per W-item)
    w-a2.md
    claims.md              # Integration claims (open + resolved)
```

Naming:
- Folder: `exec-<slug>/` (e.g. `exec-phase-1/`).
- Index: always `plan.md`.
- W-item files: `w-<id-lowercase>.md` (e.g. `w-a1.md`, `w-b3.md`).
- Claims file: always `claims.md` (created lazily — first claim filing creates it).

Introduced by [ADR-017](../architecture/adr-017-plan-folder-restructure.md). The folder shape separates runtime state (the index) from static SOW (W-item files) so that Status appears in exactly one place.

### Soft migration (plans that predate ADR-017)

Plans drafted before ADR-017 are single-file at `docs/execution-plans/<plan>.md` (e.g. `exec-phase-1.md`). These continue to work — the Orchestrator detects format in STEP 0 PRELUDE before any reconciliation runs:

- `docs/execution-plans/<plan>/plan.md` exists → **new format**. Read `plan.md` for ledger; read W-item files on demand; read `claims.md` for claims.
- `docs/execution-plans/<plan>.md` exists (and no folder of the same name) → **old format**. Read as before — single file with summary table + per-W-item sections + inline Integration claims (ADR-016 inline shape).

Both formats coexist during transition. New plans drafted after ADR-017 use the folder structure by default. Strategists migrate existing plans on a schedule that suits the project; the framework does not force migration.

## Archival

Closing a plan moves the entire folder to `docs/archive/`:

```
mv docs/execution-plans/exec-phase-1 docs/archive/
```

Single move; all artifacts preserved. The folder structure inside `docs/archive/` is identical to `docs/execution-plans/`. Single-file plans archived under the old format remain valid in `docs/archive/` as standalone files — soft migration applies to archives too.

After moving:
1. Add a one-line summary to `docs/archive/README.md`.
2. Remove from CLAUDE.md's active-plan pointer if it named this plan.

**Closed plans are never in the session-start reading list.** This is how context stays manageable — see `docs/dev_framework/context-management.md`.

## Size limits

- **Index (`plan.md`)** — under **150 lines / 15 W-items**. Larger initiatives split into focused sub-plans by stream or theme.
- **W-item file** — under **200 lines**. If a W-item file is growing past 200 lines, the work item itself is too big — split it into multiple W-items.

These bounds keep each artifact readable within a session's context budget. Per-dispatch reads stay scoped to the W-item the agent is working on, not the full phase.

## The index (`plan.md`)

The index is the runtime ledger. It carries:

- A summary table — one row per W-item.
- A pointer to `claims.md` if the plan has any claims.
- An optional Notes section — runtime event log, per W-item.

### Summary table

```markdown
| W-id | Title | Effort | Markers | Status | Branch |
|------|-------|--------|---------|--------|--------|
| W-A1 | [Auth alignment](w-a1.md) | S | ⚠️ | done | w-a1/auth |
| W-A2 | [Task claim](w-a2.md) | M | ⚠️ | held | w-a2/task-claim |
| W-A3 | [Webhook retry](w-a3.md) | S | — | pending | — |
```

The Title cell links to the W-item file. Dispatch-relevant fields (Effort, Markers, Status, Branch) sit on the index only. Branch is populated when Status becomes `in_progress`.

### Claims pointer

When the plan has any claims, the index links to `claims.md`:

```markdown
**Integration claims:** [`claims.md`](claims.md) — open: 2, resolved: 5
```

The pointer is added by whichever agent files the first claim (Integrator-QA) and updated by the Strategist as dispositions move claims between Open and Resolved.

### Notes (optional)

Below the summary table, the index may include a free-form Notes section for runtime events that don't fit a table cell:

```markdown
## Notes

### W-A2 — 2026-04-25
Stumped on auth refresh: token rotation contract unclear. User clarified rotation window; sharpened brief dispatched.
```

Notes capture stumped reasons + resolution, ship-with-concerns text, lessons-learned highlights worth keeping past the merge commit. One paragraph per event max — not a diary.

### Index fields

| Field | Purpose | Owner |
|-------|---------|-------|
| **W-id** | Unique within the plan. Format: `W-<stream><number>` (e.g. W-A1, W-B3). Streams group related items. | Strategist |
| **Title** | Short title — cell links to the W-item file. | Strategist |
| **Effort** | XS / S / M / L / XL — drives the tiered execution pattern in `session-policy.md`. | Strategist |
| **Markers** | ⚠️ architectural/irreversible (forces QA, bumps retry cap to 3). 🔍 spike/research (Orchestrator runs directly, 2h max); also applies to branch-topology work that cannot run inside a worktree. Combine with ⚠️ when destructive. 🧪 requires live QA regardless of tier. | Strategist |
| **Status** | One of `pending` / `in_progress` / `held` / `blocked` / `done` / `shipped`. Multi-writer — see transition table below. | Orchestrator (most), Integrator-QA (`in_progress → held`), Strategist (`held → in_progress / blocked`) |
| **Branch** | `w-<id>/<slug>` — populated when Status becomes `in_progress`. | Orchestrator |

## W-item files

Each W-item is its own file in the plan folder, `w-<id-lowercase>.md`. The H1 is just the W-id (e.g. `# W-A1`). Title lives on the index table only — no duplication.

Each W-item file has at most 200 lines and three sections:

```markdown
# W-A1

## High level

**What:** One sentence describing what this item produces.

**Acceptance criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

**Depends on:** W-A0 (or "—" if none)

## Execution notes

**Parallel-safe:** true | false — see §"Parallel-safe field" below. Default when unset: false.

**Parallel-safe considered:** <required when Parallel-safe is true — names the shared surfaces evaluated>

**Touches:** `src/foo.ts`, `src/bar.ts`

**References:** `src/legacy/foo.py:120-280` (auth middleware pattern) — optional read-only orientation material for the Executor.

## Contingencies

Pre-planned fallbacks, known edge cases, "if X happens, do Y" guidance. Optional — write `(none)` when nothing applies.
```

**No Status field on the W-item file.** Status lives only on the index. The W-item file is the static SOW; the index is the runtime ledger. This is the single-source rule introduced by ADR-017 — there is no second place for Status to drift to.

### W-item file fields

| Field | Section | Purpose |
|-------|---------|---------|
| **What** | High level | One sentence — what artifact does this item produce? |
| **Acceptance** | High level | Checkboxes. All must be green before the item is `done`. |
| **Depends on** | High level | Other W-ids that must be complete first. Forms the dependency graph. |
| **Parallel-safe** | Execution notes | `true` = eligible for batch-mode dispatch (ADR-016). `false` = per-task peer chain (ADR-013). Owned by the Strategist; set at plan time. Default: `false`. |
| **Parallel-safe considered** | Execution notes | Required line when Parallel-safe is `true`; names the shared surfaces the Strategist evaluated (package.json, lockfile, migrations, schema, route registry, shared test fixtures, refactor-of-a-callee). Forces the judgment to be recorded rather than mechanized. |
| **Touches** | Execution notes | Files the item will modify. Executor uses this as scope boundary. |
| **References** | Execution notes | Optional read-only orientation files with line ranges (e.g. `src/legacy/foo.py:120-280`). Intended for port / migration / refactor work where pre-existing structure must be understood. Modifying one is scope creep. |
| **Contingencies** | Contingencies | Pre-planned fallbacks and edge cases. Strategist-authored at draft time. |

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

The framework does NOT auto-derive `Parallel-safe` from `Touches`. The Strategist considers the shared surfaces above and decides explicitly. Whenever `Parallel-safe` is set to `true`, the W-item file MUST include a `Parallel-safe considered: <factors>` line naming what was evaluated — this forces the judgment to be recorded rather than mechanized.

**Default when unset:** `false`. Adopter plans that predate ADR-016 (no `Parallel-safe` field on any W-item) continue to flow through the per-task peer chain. Strategists backfill the field when they decide to opt items into batch mode. No plan breaks at sync time.

## Status state machine

Six states: `pending`, `in_progress`, `held`, `blocked`, `done`, `shipped`.

```
      ┌─────────┐
      │ pending │ ← default for newly-added W-items
      └────┬────┘
           │ Orchestrator dispatches Executor
           ▼
    ┌─────────────┐  Integrator-QA files claim    ┌──────┐
    │ in_progress │ ────────────────────────────▶ │ held │
    └──┬──────────┘                               └──┬───┘
       │  ▲                                          │
       │  │                                          │ Strategist
       │  │ Orchestrator                             │ disposes
       │  │ re-dispatches                            │
       │  │                                          │ approve/modify
       │  │ ┌─────────┐                              ├─────────────▶ in_progress
       │  └─│ blocked │ ◀─────────reject─────────────┤
       │    └─────────┘                              │ reject
       │      ▲                                      └─────────────▶ blocked
       │      │ Executor stumped /
       │      │ Integrator integration failure
       │
       │ Executor pass + Orchestrator merge
       ▼
    ┌──────┐
    │ done │
    └───┬──┘
        │ Phase exit QA + user authorize + Orchestrator promotes
        ▼
   ┌─────────┐
   │ shipped │ ← terminal
   └─────────┘
```

### Transition table

PLAN-WRITE DISCIPLINE applies to every transition: the writing agent reads the index file fresh, edits it, commits the edit alongside the trigger event (atomically — one commit, all touched files together), and verifies the push. Each writer's role doc / brief inlines the discipline at its write site.

| From → To | Trigger | Writer | Atomic with |
|---|---|---|---|
| `pending` → `in_progress` | Orchestrator about to spawn Executor | Orchestrator | Dispatch event (Status flip + Branch populate; commit before spawning) |
| `in_progress` → `done` | Executor pass + Orchestrator merges feature → `dev` | Orchestrator | The merge commit |
| `in_progress` → `blocked` | Executor stumped, or Integrator-QA integration failure (confidence <80%) | Orchestrator | Stumped notice (Status flip + index Notes line) |
| `in_progress` → `held` | Integrator-QA files an Integration claim naming the W-item | Integrator-QA | Claim filing — one commit writes both `claims.md` (new IC-NNN under Open) and `plan.md` (Status flip) |
| `held` → `in_progress` | Strategist disposes claim as `approve` or `modify` | Strategist | Disposition commit — one commit writes both `claims.md` (move to Resolved) and `plan.md` (Status flip) |
| `held` → `blocked` | Strategist disposes claim as `reject` and the rejection leaves the W-item un-actionable | Strategist | Same as above |
| `blocked` → `in_progress` | Orchestrator re-dispatches with a sharpened brief | Orchestrator | Re-dispatch (Status flip + updated Branch if changed) |
| `done` → `shipped` | Phase-exit QA passes + user authorizes + Orchestrator merges `dev` → `main` | Orchestrator | The promotion merge |

The plan is a ledger — stale entries mean the ledger is lying and a future session will dispatch duplicate work or skip done work. PLAN-WRITE DISCIPLINE is the mechanism that keeps the ledger and git in lockstep across all three writing agents.

### `held` semantics

A W-item enters `held` when an open Integration claim names it. Held items have a branch that exists; the branch is preserved during the hold (no Executor activity). Held items do NOT merge to `dev` until the claim is disposed. Other W-items in the same batch that aren't named by the claim continue to merge normally.

The `held` state replaces the convention (used in earlier ADR-016 drafts) of leaving claim-blocked items at `in_progress` with a Notes line — that approach left the Status field misleading. Under ADR-017 the Status field reflects actual state.

### Reconciliation (on session start)

A fresh Orchestrator session MUST reconcile the plan ledger against git reality before dispatching anything. See `orchestrator-bootstrap.md` STEP 0. New check under ADR-017: every `held` W-item must have a corresponding open IC-NNN entry in `claims.md`. A `held` item with no open claim is a ledger lie — surface to the user, do not auto-fix.

Summary-table-vs-W-item-section drift is structurally impossible under the folder layout (Status appears once on the index). The pre-ADR-017 STEP 0 check for that drift retires.

## Integration claims

**Filed by the Integrator-QA in batch mode (ADR-016) when a fix would require stepping outside a W-item's acceptance criteria.** The Integrator does NOT change scope unilaterally. When its confidence in a proposed scope change is ≥80%, it files an integration claim in `claims.md` and flips the named W-item(s) to `held`. The Strategist triages with the user. When confidence is <80%, the Integrator surfaces to the user immediately as a feature integration failure — no claim is filed; the W-item moves to `blocked` instead.

### Where claims live

Integration claims live in `claims.md` inside the plan folder. Two sections — Open and Resolved.

```markdown
# Integration claims — exec-phase-1

## Open

(Open claims — held W-items do not merge until the Strategist + user dispose.)

### IC-NNN — YYYY-MM-DD — {{W-id(s)}} — {{short title}}

**Filed by:** Integrator-QA, batch <ids>
**Confidence:** <pct>
**Proposed scope change:** <what Integrator wants to do but won't do unilaterally>
**Why:** <what forced the proposal — test failing for X, acceptance ambiguous on Y>
**Blocks:** <W-item ids whose merge is held pending resolution>

## Resolved

### IC-NNN — YYYY-MM-DD → resolved YYYY-MM-DD — {{title}}

**Disposition:** approve | reject | modify
**Resolution:** <one-line summary of what the Strategist + user decided>
**Follow-up:** <W-item id if the resolution opened a new item, or "none">
```

### Numbering

Sequential across the plan, `IC-001`, `IC-002`, etc. Numbers persist across open → resolved (the entry moves between sections; the number stays). The Integrator-QA assigns the next unused number when filing.

### Blocking semantics

An open claim blocks **only the named W-items** from merging — those items are at `held` Status. Other W-items in the same batch that aren't named proceed through merge normally. Other batches, sequential work, and Orchestrator forward progress are not blocked. If the Strategist's resolution modifies acceptance or opens a follow-up W-item, the held items either re-enter dispatch (with the updated acceptance, transitioning to `in_progress`) or move to `blocked` pending the follow-up — the Strategist records which in the claim's Resolution line.

### Triage

The Strategist reviews open claims at phase boundaries and on demand, in the same triage pass as `process-exceptions.md`. Dispositions:

- **approve** — Integrator's proposed change is sound. Strategist updates the W-item's acceptance / SOW (in the W-item file), moves the claim to Resolved, flips index Status `held → in_progress`. Integrator-QA re-runs its fix pass on the affected items.
- **reject** — Do not make the change. Strategist moves the claim to Resolved, flips index Status `held → blocked`. The Integrator-QA surfaces a revised plan (or a stumped return) instead.
- **modify** — Strategist revises the proposal in the Resolution line, moves claim to Resolved, flips index Status `held → in_progress`. Integrator re-runs against the revised acceptance.

Every disposition is recorded in the Resolved section. Never delete — the history is the value.

### Atomicity

Three writes touch claim state. Each is one commit:

- **Filing** (Integrator-QA) — `claims.md` (new IC-NNN under Open) AND `plan.md` (Status `in_progress → held` for named W-items). One commit, both files.
- **Disposition** (Strategist) — `claims.md` (move IC-NNN from Open to Resolved with Disposition + Resolution) AND `plan.md` (Status `held → in_progress` or `held → blocked` for named W-items). One commit, both files. If the disposition also revises acceptance, the matching W-item file edit is part of the same commit.
- **No partial states.** A `held` Status with no open claim, or an open claim with no `held` Status, is a ledger lie — see Reconciliation above.

### When a claim is NOT appropriate

- **Ordinary bugs within acceptance.** The Integrator fixes those inline; no claim.
- **Standards violations** (hardcoded values, missing tests, silent fallbacks) within acceptance. Same — the Integrator writes a fix commit per `coding-standards.md`.
- **Confidence <80%.** Surface to the user directly; W-item goes to `blocked`, not `held`. Don't hand the user a low-confidence proposal to chew on.
- **Issues the Integrator caught in its first-pass high-profile scan.** Those are surfaced immediately as feature integration failures, not claims — the distinction is that the first-pass scan catches problems that should halt the batch before deep work, whereas claims emerge from deep work that revealed an acceptance ambiguity.
