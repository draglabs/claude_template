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

### Mode-exclusivity (per phase)

The Developer and the Orchestrator both write Status to `plan.md`. Per-phase mode-exclusivity is the resolution: at plan draft, the user picks the mode that runs the phase. Switching mid-phase is heavy and discouraged — close the phase (promote `done → shipped`) and start a fresh one under the other mode.

A per-W-item `Mode` field is rejected for v1 — adds machinery for a problem we don't yet have. Per-phase is mechanically simpler (no new field on the W-item file, no per-item dispatch routing) and matches the way users actually pick modes (a phase's character is set early).

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

6. `docs/execution-plans/README.md` — `code_review` state, transitions, Developer as Status writer, Implementation log section template, mode-exclusivity note.
7. `docs/dev_framework/session-policy.md` §"Status ledger" — Developer as fourth writer.

## Consequences

**What this buys:**

- **First-class shape for conversational coding.** The user-in-the-loop mode now produces the same plan ledger, branches, and persistent record as Orchestrator mode. Work no longer has to fall outside the framework to be done conversationally.
- **Blind self-review without losing ownership.** The rewind ritual gives fresh-eyes review by clearing process context while preserving the persistent session as the work's owner. Reviewer subagents lose project context entirely; the rewound Developer keeps it via the Implementation log, the W-item file, and the diff.
- **Documented journey on the project.** The Implementation log captures what actually happened — pivots, advisor calls, decisions reversed — in a place that survives session resets and shows up next to the W-item itself. Commit messages alone don't aggregate this.

**What this costs:**

- **Fourth Status writer.** PLAN-WRITE DISCIPLINE now applies at four agent-types' write sites instead of three. Each must hold the discipline. Drift risk extends.
- **Two parallel modes for the same kind of work (coding).** Newcomers to the framework have to learn both. Mitigated by mode-exclusivity per phase — a phase has one mode, not a mix.
- **Rewind harness-coupling.** The role's signature behavior depends on a Claude Code affordance. Adopters on other harnesses get a degraded role. Documented as an exception.
- **W-item file template grows.** Fourth section (Implementation log) on the SOW file — unused in Orchestrator mode (or used optionally), populated in Developer mode. Adopters reading the template see a section that may not apply to their mode.

**What this does NOT do:**

- **Does not change Orchestrator dispatch.** ADR-013 sequential mode and ADR-016 batch mode flow unchanged. The new state `code_review` does not appear in Orchestrator-mode lifecycles.
- **Does not change claim semantics.** ADR-016's claim shape and ADR-017's claim location unchanged. Developer becomes a second filer (after Integrator-QA), but the protocol is identical.
- **Does not deprecate the Reviewer subagent.** Reviewer is still spawned in Orchestrator sequential mode (ADR-013) and absorbed by Integrator-QA in batch mode (ADR-016). Developer mode replaces Reviewer with the rewound self for its own items only.
- **Does not change phase exit gates.** Phase exit still requires QA against the dev environment + user authorization, regardless of mode. The Developer can run the phase-exit smoke pass itself or coordinate with the user to run it; the gate is not waived.

## Alternatives considered

1. **Developer as Orchestrator-dispatched Executor variant.** Rejected — subagents are stateless invocations; there is no chat to rewind, no paste interaction, no continued session post-rewind. The rewind ritual cannot be implemented in a subagent.
2. **Per-W-item `Mode` field on plan.md.** Rejected for v1 — adds machinery for a problem not yet observed (mid-phase mode mixing). Per-phase exclusivity is simpler and addresses the actual usage.
3. **Self-blind QA via spawning a Reviewer subagent.** Rejected — Reviewer subagent is ephemeral and stateless; loses the project context that makes Developer-mode work coherent. The novel value of the rewind mechanism is "same session, different context" — Reviewer subagent gives "different session, no context."
4. **Add a `qa` state.** Rejected — the user is the QA gate in real-time. State doesn't bounce between `qa` and `in_progress`; `in_progress` covers the whole loop until user confirmation. A separate `qa` state would never be observed long enough to matter.
5. **Universal Implementation log (all modes).** Deferred — Developer-mode-specific in v1 because that's where chat-rewind makes a persistent journey record load-bearing. Easy to extend if Orchestrator-mode usage shows benefit.
6. **Skip ADR; document in role doc only.** Rejected — adding a role + state machine extension + new write authority is a load-bearing decision touching seven framework surfaces. Future readers need a single decision record explaining why.

## Acceptance criteria for the shipping PR

- `docs/dev_framework/developer.md` exists, describes the role's behavior end-to-end (bootstrap, lifecycle, rewind ritual, blind review, Implementation log, claim filing).
- `CLAUDE.md` §Roles table has a Developer row with invocation trigger and bootstrap reads.
- `docs/dev_framework/dev_framework.md` has Developer in the Role docs table; the agent-stack diagram or surrounding prose names it as a parallel mode.
- `docs/dev_framework/context-management.md` Layer 1 row for Developer names `coding-standards.md` + the active plan's `plan.md` as bootstrap reads.
- `.claude/hooks/session-reorient.sh` includes "developer" in the role-list strings in all four sources (startup / resume / compact / clear).
- `docs/execution-plans/README.md`:
  - State machine adds `code_review`.
  - Transition table adds the Developer-owned transitions.
  - W-item file template adds the Implementation log section.
  - Mode-exclusivity note (per-phase) at the top of the file or near the state machine.
  - Status state count updates to **seven** (`pending`, `in_progress`, `code_review`, `held`, `blocked`, `done`, `shipped`).
- `docs/dev_framework/session-policy.md` §"Status ledger" lists Developer as a fourth writer with the transition set.
- One PR. Half-shipping any of these creates an incoherent intermediate state — agents read a role doc that names a state the spec doesn't define, or vice versa.
