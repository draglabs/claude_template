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

The index is the runtime ledger. The top of the file orients a reader; the rest tracks state.

**Top of file (plan-level, set at draft, rarely revised):**

- An H1 plan title — a phrase a fresh reader understands without context, not the folder slug.
- An **Executive summary** section — Goal, Scope, Out of scope, Success criteria.

**Below that (runtime, mutable):**

- A summary table — one row per W-item.
- A pointer to `claims.md` if the plan has any claims.
- An optional Notes section — runtime event log, per W-item.

### Plan title and executive summary

The first two sections orient any agent or human opening the plan: what is this phase trying to accomplish, what's intentionally not in it, when does it close.

```markdown
# Phase 1: Auth and tenancy foundation

## Executive summary

**Mode:** orchestrator

**Goal:** Establish multi-tenant auth and per-tenant data isolation as the substrate every later feature depends on.

**Scope:**
- Email + OAuth login
- Tenant model with row-level isolation
- Session management

**Out of scope:**
- SSO / SAML (deferred to Phase 3)
- Tenant-level RBAC (Phase 2)

**Success criteria:**
- All W-items `done` and merged to `dev`
- Phase-exit QA against `{{sub}}.dev.{{website}}.com` green
- User authorizes promotion to `main`
```

The Strategist writes these at plan-draft time. They are not runtime ledger fields — phase pivots may revise them; routine W-item progress does not.

#### Mode field (mode-exclusivity mechanism)

`Mode` determines which dispatch flow runs the plan. Allowed values:

- **`orchestrator`** — default. ADR-013 sequential or ADR-016 batch dispatch through Executor / Reviewer / QA peer subagents.
- **`developer`** — ADR-018 hands-on, user-invoked Developer with rewind ritual + blind self-review.

The Strategist sets `Mode` at plan draft. Both the Orchestrator's STEP 0 PRELUDE and the Developer's bootstrap read this field and **refuse to act on a plan that doesn't match their mode** — this is the mechanism behind mode-exclusivity per phase ([ADR-018](../architecture/adr-018-developer-role.md)). Mismatches surface to the user; no auto-resolution.

Pre-ADR-018 plans lack this field; both bootstraps interpret absent `Mode` as `orchestrator` for back-compat. Strategists migrating a phase to Developer mode set the field explicitly at draft.

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

## Implementation log

Appended by the Developer at `code_review → done` (Developer mode only in v1; ADR-018). Absent until that flip — the section header does not appear on a W-item file at draft.

**Approach:** One paragraph on how the work was actually done.

**Key decisions:**
- Decision 1 — why
- Decision 2 — why

**Pivots:**
- What was tried first, why it didn't work, what replaced it (or `none`).

**Surprises:**
- Anything the work uncovered that future readers should know (or `none`).

**Followups / loose ends:**
- Anything intentionally deferred (or `none`).
```

**No Status field on the W-item file.** Status lives only on the index. The W-item file is the static SOW; the index is the runtime ledger. This is the single-source rule introduced by ADR-017 — there is no second place for Status to drift to.

The Implementation log is the one section that gets appended after draft, at the `code_review → done` flip. It is append-only (not mutated after merge) and therefore does not reintroduce drift bait — see ADR-018.

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
| **Implementation log** | Implementation log (post-completion) | Appended by the Developer at `code_review → done` flip. Captures approach, key decisions, pivots, surprises, followups. Compensates for chat-rewind discarding session journey. Developer mode only in v1 (ADR-018). |

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

Seven states: `pending`, `in_progress`, `code_review`, `held`, `blocked`, `done`, `shipped`.

The state machine has two mode-specific lifecycles. Orchestrator mode (ADR-013 sequential, ADR-016 batch) and Developer mode (ADR-018) share `pending`, `held`, `blocked`, `done`, `shipped` and the `held`/`blocked` recovery transitions. The middle of the lifecycle differs:

- **Orchestrator mode** runs `in_progress → done` — Reviewer + QA gates run as peer subagents.
- **Developer mode** runs `in_progress → code_review → done` — user mediates QA inside `in_progress` (no separate `qa` state); rewind ritual + blind self-review covers the `code_review` step.

A given W-item runs through one mode's lifecycle at a time, by per-phase mode-exclusivity (see §"Mode-exclusivity" below).

### Orchestrator-mode lifecycle

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

### Developer-mode lifecycle

```
   pending ──▶ in_progress ──▶ code_review ──▶ done ──▶ shipped
                  │     ▲          │    ▲                  ▲
                  │     │          │    │                  │
                  │     │          │    │ self-review      │ phase exit
                  │     │          │    │ block, user      │ + user authorize
                  │     │          │    │ re-engages       │ + Developer promotes
                  │     │          │    │
                  │     │          │    └────── (manual; not auto-loop)
                  │     │          │
                  │     │          │ blind self-review pass
                  │     │          │ + merge to dev
                  │     │          │ + Implementation log on W-item file
                  │     │          ▼
                  │     │       (continue to done)
                  │     │
                  │     │ user confirms feature works
                  │     │ → flip happens here, atomic with rewind summary commit
                  │     │
                  │     └──── user mediates QA loop inside in_progress
                  │            (Developer codes, user tests, iterate)
                  │
                  ├─▶ held (Developer files claim; rare; Strategist disposes
                  │         as in Orchestrator mode)
                  │
                  └─▶ blocked (unblockable; user can't move it forward)
```

Anchor moment: the Developer asks the user "ready to start coding W-X?" before the `pending → in_progress` flip. The user notes this as the chat-rewind anchor — at the `in_progress → code_review` flip, the Developer recommends rewinding chat to this point and pasting the rewind summary, putting the Developer's session into clean context for the blind self-review.

### Mode-exclusivity (per phase)

Orchestrator mode and Developer mode both write Status to `plan.md`. PLAN-WRITE DISCIPLINE protects against file races, but not against semantic ambiguity if both modes touch the same W-item — Orchestrator's `pending → in_progress → done` and Developer's `pending → in_progress → code_review → done` interpret `in_progress` differently.

Resolution: **one mode per phase, picked at draft time.** A phase runs end-to-end under either Orchestrator dispatch or Developer mode; do not mix on the same plan. Switching modes mid-phase is heavy — close the phase (`done → shipped`) and start a fresh one under the other mode.

A per-W-item `Mode` field is a possible future extension if usage shows mid-phase mixing is needed. Not in v1 (ADR-018).

### Transition table

PLAN-WRITE DISCIPLINE applies to every transition: the writing agent reads the index file fresh, edits it, commits the edit alongside the trigger event (atomically — one commit, all touched files together), and verifies the push. Each writer's role doc / brief inlines the discipline at its write site.

| From → To | Mode | Trigger | Writer | Atomic with |
|---|---|---|---|---|
| `pending` → `in_progress` | Orch | Orchestrator about to spawn Executor | Orchestrator | Dispatch event (Status flip + Branch populate; commit before spawning) |
| `pending` → `in_progress` | Dev | Developer claims item after user confirms "ready to start coding" | Developer | Branch creation + anchor message; one plan-write commit |
| `in_progress` → `done` | Orch | Executor pass + Orchestrator merges feature → `dev` | Orchestrator | The merge commit |
| `in_progress` → `code_review` | Dev | User confirms feature works; Developer drafts rewind summary | Developer | Rewind summary commit on the W-item branch |
| `code_review` → `done` | Dev | Developer's blind self-review passes; merge to `dev` | Developer | Merge commit + Implementation log on W-item file |
| `code_review` → `in_progress` | Dev | Self-review surfaces a serious finding; user re-engages | Developer | Re-dispatch (user-mediated, NOT auto-loop) |
| `in_progress` → `blocked` | Orch | Executor stumped, or Integrator-QA integration failure (confidence <80%) | Orchestrator | Stumped notice (Status flip + index Notes line) |
| `in_progress` → `blocked` | Dev | Unblockable issue; user can't move work forward | Developer | Stumped notice (Status flip + index Notes line) |
| `in_progress` → `held` | Orch (batch) | Integrator-QA files a claim naming the W-item | Integrator-QA | Claim filing — one commit writes `claims.md` (IC-NNN under Open) + `plan.md` (Status flip) |
| `in_progress` → `held` | Dev | Developer files a claim mid-work (rare; ≥80% confidence acceptance ambiguity) | Developer | Claim filing — same shape as Integrator-QA |
| `held` → `in_progress` | Both | Strategist disposes claim `approve` / `modify` | Strategist | Disposition — one commit moves IC-NNN to Resolved + flips Status |
| `held` → `blocked` | Both | Strategist disposes claim `reject` and W-item is un-actionable | Strategist | Same as above |
| `blocked` → `in_progress` | Orch | Orchestrator re-dispatches with a sharpened brief | Orchestrator | Re-dispatch (Status flip + updated Branch if changed) |
| `done` → `shipped` | Both | Phase-exit QA passes + user authorizes + active mode promotes `dev → main` | Orchestrator (Orch-driven phase) or Developer (Dev-driven phase) | The promotion merge |

The plan is a ledger — stale entries mean the ledger is lying and a future session will dispatch duplicate work or skip done work. PLAN-WRITE DISCIPLINE is the mechanism that keeps the ledger and git in lockstep across all four writing agents.

### `held` semantics

A W-item enters `held` when an open Integration claim names it. Filer depends on mode:

- **Orchestrator (batch) mode:** Integrator-QA files when an integration fix would step outside acceptance (ADR-016).
- **Developer mode:** the Developer files mid-work when it identifies acceptance ambiguity at ≥80% confidence (ADR-018, rare path; most ambiguity resolves with the user in real-time).

In both cases: held items have a branch that exists, the branch is preserved during the hold (no Executor or Developer activity), held items do NOT merge to `dev` until the claim is disposed. Strategist disposes per the standard claim flow (`held → in_progress / blocked`).

The `held` state replaces the convention (used in earlier ADR-016 drafts) of leaving claim-blocked items at `in_progress` with a Notes line — that approach left the Status field misleading.

### `code_review` semantics

A W-item enters `code_review` only in Developer mode, when the user has confirmed the feature works and the Developer is preparing the rewind hand-off. The branch carries the implementation; the rewind summary has been committed; the Developer has recommended the user rewind chat and paste the summary. Post-rewind, the Developer reads `plan.md`, sees the item at `code_review`, and performs blind self-review.

Two outcomes:

- **Pass.** Merge to `dev`, write Implementation log on the W-item file, flip `code_review → done` in one commit.
- **Block.** Surface findings to user. Path back to `in_progress` is user-mediated — the Developer does not auto-loop. The user chooses: fix-and-retry (`code_review → in_progress`), ship-with-known-limitation (recorded as a user override in the Implementation log + plan Notes; flip to `done`), or escalate.

### Reconciliation (on session start)

A fresh Orchestrator session MUST reconcile the plan ledger against git reality before dispatching anything. See `orchestrator-bootstrap.md` STEP 0. Check under ADR-017: every `held` W-item must have a corresponding open IC-NNN entry in `claims.md`. A `held` item with no open claim is a ledger lie — surface to the user, do not auto-fix.

A fresh Developer session reconciles similarly per its bootstrap (`developer.md`). The state IS the memory:

- Item at `code_review` → post-rewind blind-self-review path; propose to do that before any new work.
- Item at `in_progress` after a context reset → ambiguous (mid-coding before rewind, or mid-QA-loop). Confirm with user.
- Item at `held` → awaiting Strategist disposition; skip.
- Otherwise → propose top `pending` item by critical path (Depends-on graph).

Summary-table-vs-W-item-section drift is structurally impossible under the folder layout (Status appears once on the index). The pre-ADR-017 STEP 0 check for that drift retires.

## Integration claims

**Filed by the Integrator-QA in batch mode (ADR-016), or by the Developer in Developer mode (ADR-018), when a fix would require stepping outside a W-item's acceptance criteria.** The filer does NOT change scope unilaterally. When confidence in a proposed scope change is ≥80%, the filer adds an integration claim to `claims.md` and flips the named W-item(s) to `held`. The Strategist triages with the user. When confidence is <80%, the filer surfaces to the user immediately as a feature failure — no claim is filed; the W-item moves to `blocked` instead.

In Developer mode the rare-path filing is described in [`developer.md`](../dev_framework/developer.md) §"Claim-filing (rare path)" — most acceptance ambiguity in Developer mode resolves with the user in real-time, but a claim is appropriate when the change has cross-W-item implications or the user isn't immediately available to confirm.

### Where claims live

Integration claims live in `claims.md` inside the plan folder. Two sections — Open and Resolved.

```markdown
# Integration claims — exec-phase-1

## Open

(Open claims — held W-items do not merge until the Strategist + user dispose.)

### IC-NNN — YYYY-MM-DD — {{W-id(s)}} — {{short title}}

**Filed by:** Integrator-QA (batch <ids>) | Developer (Dev-mode session, ADR-018)
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
