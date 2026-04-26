# ADR-018: Developer role with rewind doctrine

**Status:** accepted
**Date:** 2026-04-25
**Deciders:** David (template author), Template Developer session

## Context

The framework has a single dispatch model: User ↔ Orchestrator → Executor → Reviewer → QA. It is well-suited to autonomous batch work where the user wants to be hands-off. It is poorly suited to work where the user wants to be in the loop — driving the test cadence personally, talking to the coding agent conversationally, calling pivots in real-time.

Two specific frictions surfaced:

1. **Conversational coding has no first-class shape.** The user can talk to a Claude Code session and code with it directly today, but doing so leaves the framework's plan ledger behind — Status doesn't flip, branches aren't tracked, the artifacts the framework expects (W-item file references, lessons learned in commits, plan-side Notes) aren't produced. The user-in-the-loop mode exists in practice as ad-hoc work outside the SOP.

2. **Self-review by the same agent is biased.** A Reviewer subagent (Orchestrator mode) gets fresh-eyes review by being a different process, but it loses project context too — it never wrote the work, never talked to the user about it, never made the calls. The user wanted a third option: same persistent owner for the work and the review, but with the journey of the work wiped from session context. Concrete mechanism: the Claude Code chat-rewind affordance — back the chat up to a checkpoint, paste a summary as if to say "it's already done," and the session reads the work fresh.

The rewind mechanism is novel. It enables blind self-review without spawning a separate agent and without losing the persistent ownership.

## Decision

Add a fourth product-side persistent role, **Developer**, that operates as a parallel mode to Orchestrator dispatch. The Developer is user-invoked, drives one W-item at a time conversationally, runs a user-mediated QA loop within `in_progress`, produces a rewind summary at done-of-coding, and post-rewind performs blind self-review on its own work using clean context.

### Mode field is advisory, not binding (v2)

The Developer and the Orchestrator both write Status to `plan.md`. The collision concern is per-W-item, not per-plan: an item can only run one mode's Status path (Orchestrator's `in_progress → done` or Developer's `in_progress → code_review → done`), and Status paths take different routes from `in_progress` so they cannot overlap.

A `**Mode**` field in the plan's Executive summary records the Strategist's recommended execution style — `orchestrator`, `developer`, or absent for no recommendation. **The field is advisory.** Either mode can claim any `pending` item on any plan. The Strategist's recommendation is a hint, not a lock.

Both bootstraps read the field on session start:

- The Orchestrator's STEP 0 MODE AWARENESS (in `orchestrator-bootstrap.md`) reads `Mode`. If `developer` (explicit), it **prompts the user** to confirm proceeding in Orchestrator mode anyway. If `orchestrator` or absent, proceeds normally.
- The Developer's bootstrap (in `developer.md`) reads `Mode`. If `orchestrator` (explicit), prompts the user to confirm proceeding in Developer mode anyway. If `developer` or absent, proceeds normally.

Items lock into a mode at claim time via the Status path they take. Per-W-item collision is naturally enforced; no plan-level lock is needed. **Mixed-mode phases are allowed** — a single plan can have some items running under Orchestrator dispatch and others running under Developer mode in parallel. The cost is historical asymmetry (early items have no Implementation log; later items do), which is tolerable.

Claim attribution lives in the plan's Notes section (`"W-A1 — claimed by Developer YYYY-MM-DD"`), written atomically with the `pending → in_progress` flip. This gives a fresh session unambiguous attribution for in-flight items even before Status leaves `in_progress`.

#### Revision (v2)

ADR-018 originally specified per-phase mode-exclusivity enforced via the Mode field with refuse-on-mismatch. Field testing showed this was over-strict — it locked the Developer out of plans the Strategist had drafted with Orchestrator in mind, even when no W-item had been claimed and no collision was possible. The doctrine "rule + mechanism in the same PR" was satisfied, but the rule itself was wrong.

The correct read: per-W-item Status paths are the natural collision boundary. Per-plan exclusivity adds friction without reducing collision risk. v2 (current) walks back to: Mode field as advisory recommendation, prompt-on-explicit-mismatch instead of refuse, mixed-mode phases allowed, claim attribution in Notes for at-a-glance ownership.

A **per-W-item** `Mode` override field is also rejected — once items lock into a mode at claim time via Status path, the override field would be redundant. The Notes-line attribution + Status-path inference covers what a per-item Mode field would cover.

### State machine extension: `code_review`

Add one new state — `code_review`. The full lifecycle for Developer-mode items:

```
pending → in_progress → code_review → done → shipped
              │              │
              │              └─(self-review serious; user re-engages)──→ in_progress
              │
              ├─(unblockable)──→ blocked
              │
              └─(acceptance ambiguity; claim)──→ held ──→ in_progress / blocked (Strategist)
```

**No `qa` state.** User-mediated QA happens inside `in_progress`. `in_progress` exits only when the user confirms the feature works. Adding a `qa` state was rejected because the user is personally pushing items through QA — there's no automatic bounce, no asynchronous wait — so a separate Status value would never be observed long enough to matter.

**`code_review → in_progress` is user-mediated, not automatic.** Unlike the Orchestrator's Reviewer-block re-dispatch (where the Orchestrator auto-loops with concerns as a sharpened brief), a self-review block requires the user to engage. The Developer surfaces findings; the user decides whether to fix-and-retry, ship-with-known-limitation, or block.

### Developer as fourth Status writer

Status writers expand from three to four:

- **Orchestrator** — owns Orchestrator-mode transitions (unchanged).
- **Integrator-QA** — owns `in_progress → held` in batch mode (unchanged).
- **Strategist** — owns `held → in_progress / blocked` (unchanged).
- **Developer** — owns Developer-mode transitions: `pending → in_progress`, `in_progress → code_review`, `in_progress → held` (rare), `in_progress → blocked`, `code_review → in_progress` (user-mediated), `code_review → done`, `done → shipped` (when phase is Developer-driven).

PLAN-WRITE DISCIPLINE applies at every Developer write site, same form as the other three writers: read fresh, edit, single commit alongside trigger event, verify pushed.

### Implementation log on W-item file

Adds a fourth section to the W-item file template — appended by the Developer at `code_review → done` flip, atomic with the merge commit:

```markdown
## Implementation log

**Approach:** One paragraph on how the work was actually done.
**Key decisions:** ...
**Pivots:** ...
**Surprises:** ...
**Followups / loose ends:** ...
```

This is **Developer-mode-specific** in v1. The chat-rewind discards session journey; the Implementation log persists it on the project. Other modes (Orchestrator-dispatched Executor) capture journey in commit messages and the plan's Notes section already; extending Implementation log to those modes is an option for the future, not v1.

The Implementation log does NOT violate ADR-017's "static SOW" principle for the W-item file. The log is appended at done-flip and is then static for the lifetime of the project. ADR-017 was about preventing Status drift via mid-flight runtime mutations of the W-item file. A done-flip append is a different shape and does not reintroduce drift bait.

### Rewind ritual is harness-specific

The rewind summary + chat-history-rewind is a **Claude Code-specific** affordance. Adopters running on other harnesses use the Developer role minus the ritual — fall back to spawning a Reviewer subagent (Orchestrator-mode mechanism) for code review of Developer-driven items, or omit blind review and rely on user QA + Implementation log alone. The deviation gets recorded in `dev_framework_exceptions.md` per the standard exception protocol.

### Five-surface role-add

Per the framework-change doctrine: adding a role updates five surfaces in one PR.

1. `docs/dev_framework/developer.md` — the role doc itself.
2. `CLAUDE.md` §Roles table — invocation trigger + bootstrap reads.
3. `docs/dev_framework/dev_framework.md` §Role docs — role row + brief mention in agent stack.
4. `docs/dev_framework/context-management.md` Layer 1 — bootstrap reading set, including `coding-standards.md` (Developer writes code, unlike Orchestrator/Strategist).
5. `.claude/hooks/session-reorient.sh` — add "developer" to the role-list strings in all four sources (startup / resume / compact / clear).

Plus the spec/doc updates:

6. `docs/execution-plans/README.md` — `code_review` state, transitions, Developer as Status writer, Implementation log section template, Mode field as advisory recommendation, §"Mode signaling (per item, not per phase)" with the v1→v2 walk-back rationale.
7. `docs/dev_framework/session-policy.md` §"Status ledger" — Developer as fourth writer.

## Consequences

**What this buys:**

- **First-class shape for conversational coding.** The user-in-the-loop mode now produces the same plan ledger, branches, and persistent record as Orchestrator mode. Work no longer has to fall outside the framework to be done conversationally.
- **Blind self-review without losing ownership.** The rewind ritual gives fresh-eyes review by clearing process context while preserving the persistent session as the work's owner. Reviewer subagents lose project context entirely; the rewound Developer keeps it via the Implementation log, the W-item file, and the diff.
- **Documented journey on the project.** The Implementation log captures what actually happened — pivots, advisor calls, decisions reversed — in a place that survives session resets and shows up next to the W-item itself. Commit messages alone don't aggregate this.
- **Disciplined escalation.** The Developer follows an **80/20 confidence ladder** at decision forks (self ≥80% → act; self <80% → advisor or consultant subagent; advisor <80% → escalate to user), consistent with Integrator-QA's claim-filing threshold. Mechanizes "when to interrupt the user" so the dialogue stays high-signal. Detail in `developer.md` §"Confidence-driven escalation (80/20 rule)".

**What this costs:**

- **Fourth Status writer.** PLAN-WRITE DISCIPLINE now applies at four agent-types' write sites instead of three. Each must hold the discipline. Drift risk extends.
- **Two parallel modes for the same kind of work (coding).** Newcomers to the framework have to learn both. Mitigated by per-plan Mode field as the Strategist's recommendation + prompt-on-explicit-mismatch in both bootstraps. Per-W-item collision is naturally prevented by mode-specific Status paths.
- **Rewind harness-coupling.** The role's signature behavior depends on a Claude Code affordance. Adopters on other harnesses get a degraded role with the Reviewer-subagent fallback documented in `dev_framework_exceptions.md`.
- **W-item file template grows.** Fourth section (Implementation log) on the SOW file — unused in Orchestrator mode (or used optionally), populated in Developer mode. Adopters reading the template see a section that may not apply to their mode.
- **One more field on `plan.md`.** Mode adds a single line in the Executive summary. Cheap, advisory — Strategists set it explicitly when they have a recommendation; absent means no recommendation expressed (no penalty in v2).

**What this does NOT do:**

- **Does not change Orchestrator dispatch.** ADR-013 sequential mode and ADR-016 batch mode flow unchanged. The new state `code_review` does not appear in Orchestrator-mode lifecycles.
- **Does not change claim semantics.** ADR-016's claim shape and ADR-017's claim location unchanged. Developer becomes a second filer (after Integrator-QA), but the protocol is identical.
- **Does not deprecate the Reviewer subagent.** Reviewer is still spawned in Orchestrator sequential mode (ADR-013) and absorbed by Integrator-QA in batch mode (ADR-016). Developer mode replaces Reviewer with the rewound self for its own items only.
- **Does not change phase exit gates.** Phase exit still requires QA against the dev environment + user authorization, regardless of mode. The Developer can run the phase-exit smoke pass itself or coordinate with the user to run it; the gate is not waived.

## Alternatives considered

1. **Developer as Orchestrator-dispatched Executor variant.** Rejected — subagents are stateless invocations; there is no chat to rewind, no paste interaction, no continued session post-rewind. The rewind ritual cannot be implemented in a subagent.
2. **Per-W-item `Mode` field on plan.md.** Rejected — once items lock into a mode at claim time via Status path (Developer's `in_progress → code_review → done` versus Orchestrator's `in_progress → done`), an explicit per-item field would be redundant. Notes-section claim attribution (`"W-A1 — claimed by Developer YYYY-MM-DD"`) covers at-a-glance ownership for in-flight items.

   **Per-plan binding Mode field with refuse-on-mismatch (original ADR-018 v1, walked back in v2).** Initially specified as the mechanism behind per-phase mode-exclusivity. Walked back after field testing showed it locked the Developer out of Strategist-drafted Orchestrator plans even when no W-item had been claimed. The actual collision boundary is per-W-item (enforced by Status paths), not per-plan. v2 reframes Mode as advisory with prompt-on-explicit-mismatch instead of refuse.
3. **Self-blind QA via spawning a Reviewer subagent.** Rejected — Reviewer subagent is ephemeral and stateless; loses the project context that makes Developer-mode work coherent. The novel value of the rewind mechanism is "same session, different context" — Reviewer subagent gives "different session, no context."
4. **Add a `qa` state.** Rejected — the user is the QA gate in real-time. State doesn't bounce between `qa` and `in_progress`; `in_progress` covers the whole loop until user confirmation. A separate `qa` state would never be observed long enough to matter.
5. **Universal Implementation log (all modes).** Deferred — Developer-mode-specific in v1 because that's where chat-rewind makes a persistent journey record load-bearing. Easy to extend if Orchestrator-mode usage shows benefit.
6. **Skip ADR; document in role doc only.** Rejected — adding a role + state machine extension + new write authority is a load-bearing decision touching seven framework surfaces. Future readers need a single decision record explaining why.

## Acceptance criteria for the shipping PR

- `docs/dev_framework/developer.md` exists, describes the role's behavior end-to-end (bootstrap with Mode check, lifecycle, rewind ritual, blind review, Implementation log, claim filing). Tightens the "does not spawn subagents" clause to default-flow only, with the Reviewer-fallback harness exception named explicitly.
- `CLAUDE.md` §Roles table has a Developer row with invocation trigger and bootstrap reads.
- `docs/dev_framework/dev_framework.md` has Developer in the Role docs table; the agent-stack diagram or surrounding prose names it as a parallel mode.
- `docs/dev_framework/context-management.md` Layer 1 row for Developer names `coding-standards.md` + the active plan's `plan.md` as bootstrap reads.
- `.claude/hooks/session-reorient.sh` includes "developer" in the role-list strings in all four sources (startup / resume / compact / clear).
- `docs/execution-plans/README.md`:
  - State machine adds `code_review`.
  - Transition table adds the Developer-owned transitions.
  - W-item file template adds the Implementation log section.
  - **Mode field** documented in the Executive summary spec as the Strategist's advisory recommendation (allowed values `orchestrator` / `developer` / absent; prompt-on-explicit-mismatch in both bootstraps; mixed-mode phases allowed).
  - Status state count updates to **seven** (`pending`, `in_progress`, `code_review`, `held`, `blocked`, `done`, `shipped`).
  - Claim-filer set expanded (Integrator-QA OR Developer) in §"Integration claims" + Filed-by template.
- `docs/dev_framework/session-policy.md` §"Status ledger" lists Developer as a fourth writer with the transition set.
- `docs/dev_framework/strategist.md` updates the claim-filer set in the Integration-claims-triage bullet (Integrator-QA OR Developer).
- `docs/dev_framework/templates/orchestrator-bootstrap.md`:
  - Multi-writer note expanded to four writers including Developer-mode transitions.
  - **STEP 0 MODE CHECK** added between PRELUDE format detection and the ledger-reconciliation paragraph; refuses on `Mode: developer`.
- One PR. Half-shipping any of these creates an incoherent intermediate state — agents read a role doc that names a state the spec doesn't define, or vice versa.
