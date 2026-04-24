# Dev framework

The SOP for how agents operate on this repo. One doc, pointers to the rest.

Linked from `CLAUDE.md`; every session reads CLAUDE.md at start, then loads what its role needs from here.

## What this is

A multi-instance model where three **product-side** persistent Claude Code sessions coordinate via git (PRs and branches), each with a narrow context budget:

- **Strategist** — the architect. Owns planning docs. Doesn't read code.
- **Designer** — owns UI mockups. Writes only to `mockups/`.
- **Orchestrator** — dispatches implementation work and coordinates peer review gates. Doesn't write code (except emergency bypass — see [`session-policy.md`](session-policy.md) §"When to suspend this policy").

Work gets done via **peer dispatch**: the Orchestrator spawns an **Executor** (who writes + commits), then spawns a **Reviewer** and, when required, a **QA** as peer subagents of the Executor. The Orchestrator owns the retry loop — on a Reviewer `block` or QA `fail`, it dispatches a fresh Executor with the concerns as sharpened context. See [`session-policy.md`](session-policy.md) §"Dispatch flow" and [ADR-013](../architecture/adr-013-peer-dispatch.md) for the full model and rationale.

A fourth role, **Template Developer**, maintains the canonical `claude_template` repo itself (the framework docs, hooks, ADRs, and managed CLAUDE.md block that every adopter inherits via destructive sync). It is only meaningful when operating in the template repo; in adopter repos the role is inert and framework changes are made by opening a PR against the template. Template Developer sits outside the product-side stack — it does not dispatch Executors, does not produce product artifacts, and does not interact with the three product-side roles during a session. See [`template-developer.md`](template-developer.md) and [ADR-015](../architecture/adr-015-template-developer-role.md).

## The agent stack

```
User ↔ Strategist          (doc-only, opens planning: PRs)
User ↔ Designer            (mockups/ only, opens design: PRs)
User ↔ Orchestrator        (dispatcher + review coordinator + merger)
           │
           ├─▶ Executor (Sonnet, worktree off `dev`)  ── code-only return
           │
           ├─▶ Reviewer (Opus)                        ── verdict to Orchestrator
           │       │
           │       └─ block? Orchestrator re-dispatches Executor with
           │         concerns as sharpened brief; retries capped per tier
           │
           ├─▶ QA (Sonnet, when required)             ── verdict to Orchestrator
           │       │
           │       └─ fail? same retry loop
           │
           ▼  all gates green
       Orchestrator ──▶ merge to `dev` ──▶ push ──▶ auto-advance
                                                       │
                         (when phase complete ─────────┘
                          + phase-exit QA + user OK)
                                │
                                ▼
                        merge `dev` → `main`
                                │
                                ▼
                     production CI deploy
```

Every subagent is a peer under the Orchestrator — no subagent spawns another subagent (hard constraint of the Claude Agent SDK; see [ADR-013](../architecture/adr-013-peer-dispatch.md)). The Orchestrator never opens diffs or source files; it reads Reviewer, QA, and Integrator-QA verdicts (which cite `file:line`). Main only moves at phase-exit promotion.

The stack above shows sequential (per-task) dispatch. For W-items marked `Parallel-safe: true` on the plan, the Orchestrator uses **batch mode** ([ADR-016](../architecture/adr-016-batch-mode-integrator-qa.md)): up to ~3 Executors dispatched concurrently, followed by a single **Integrator-QA** (Opus 1M) call that absorbs per-task Reviewer + pre-merge QA for the batch, writes fix commits within acceptance, files integration claims for scope changes (routed through Strategist + user), and merges the clean items to dev. Sequential mode and batch mode coexist — the choice is per-item at dispatch time, based on the `Parallel-safe` field.

## Role docs

| Role | Doc | Session-start reads |
|---|---|---|
| Strategist | [`strategist.md`](strategist.md) | strategist.md + planning docs |
| Designer | [`designer.md`](designer.md) | designer.md + main app UI components |
| Orchestrator | [`session-policy.md`](session-policy.md) | session-policy.md + active execution plan |
| Template Developer | [`template-developer.md`](template-developer.md) | template-developer.md + dev_framework.md (template repo only; no-op in adopter repos) |

Subagent briefs (load on spawn, not at session start):

| Role | Brief | Spawned by |
|---|---|---|
| Executor | [`templates/executor-brief.md`](templates/executor-brief.md) | Orchestrator (both modes) |
| Reviewer | [`templates/reviewer-brief.md`](templates/reviewer-brief.md) | Orchestrator — **sequential mode only**, peer of Executor |
| QA | [`templates/qa-brief.md`](templates/qa-brief.md) | Orchestrator — per-W-item pre-merge (**sequential mode only**), phase exit (both modes), post-promotion smoke (both modes) |
| Integrator-QA | [`templates/integrator-qa-brief.md`](templates/integrator-qa-brief.md) | Orchestrator — **batch mode only**, end of parallel batch; absorbs per-task Reviewer + pre-merge QA |
| Doc Consultant | [`templates/doc-consultant-brief.md`](templates/doc-consultant-brief.md) | Any role |
| Code Consultant | [`templates/code-consultant-brief.md`](templates/code-consultant-brief.md) | Primarily Strategist |
| Orchestrator bootstrap | [`templates/orchestrator-bootstrap.md`](templates/orchestrator-bootstrap.md) | User, in a fresh session |

## Enforced practices

| Concern | Canonical doc | Who loads it |
|---|---|---|
| Execution policy (tiers, retries, escalation) | [`session-policy.md`](session-policy.md) | Orchestrator |
| Coding standards (TDD, no hardcoded values, fail loudly) | [`coding-standards.md`](coding-standards.md) | Executor + Reviewer (never Orchestrator or Strategist) |
| Context budget (what each role loads) | [`context-management.md`](context-management.md) | Reference — loaded on demand |
| Approved MCPs (tools each role uses) | [`approved-mcps.md`](approved-mcps.md) | Reference — loaded when adding or evaluating an MCP |
| Dev environment (local vs remote `{{sub}}.dev.{{website}}.com`) | [`dev-environment.md`](dev-environment.md) | Orchestrator on first-time setup; loaded on demand otherwise |
| Process exceptions (raw field reports from agents) | [`process-exceptions.md`](../framework_exceptions/process-exceptions.md) | Appended to by any agent that hits process friction; read by Strategist at phase boundaries |
| Process incidents (analyzed: root cause + fix) | [`execution-incidents.md`](../framework_exceptions/execution-incidents.md) | Promoted from process-exceptions by Strategist when an entry warrants full post-mortem |

## PR-based handoff between instances

| Instance | Coordinates via |
|---|---|
| Strategist | Opens `planning:` PRs with feature specs and roadmap changes |
| Designer | Opens `design:` PRs with mockup concepts (user approves before actionable) |
| Orchestrator | Reads `planning:` and `design:` PRs via `gh pr list --label`, merges to acknowledge, then dispatches Executors on `w-<id>/<slug>` branches |

This is async-safe: each instance operates on its own surface, signals work via PR labels, and never blocks the others.

## Branch model

```
feature  ──▶  dev  ──(phase exit + user authorizes)──▶  main
              │                                          │
              ▼                                          ▼
     dev environment                            production
     (local or remote)                          (always CI-deployed)
```

Feature branches merge to `dev` per W-item (Orchestrator decision). Dev promotes to `main` only at phase-exit, gated by QA against `{{sub}}.dev.{{website}}.com` and explicit user authorization. See [`session-policy.md`](session-policy.md) §"Branching and isolation" and §"Phase exit gate."

## Two process rules (every session)

1. **Docs before code.** Architectural additions get documented by the Strategist and merged before the Orchestrator dispatches implementation. Enforced at the merge boundary by the Reviewer (`block` if no matching doc) and at the phase boundary by the Strategist's alignment audit.
2. **CI-only deploys to production.** Production changes land via `git push origin main` → CI. Never from a laptop. Never via `docker exec`. Dev environment behavior depends on mode — see [`dev-environment.md`](dev-environment.md).

Code-level rules (TDD, no hardcoded lifecycle values, fail loudly) live in [`coding-standards.md`](coding-standards.md) and are enforced by the Executor (writing) and Reviewer (checking) subagent briefs. The Orchestrator and Strategist do NOT load that doc — they delegate enforcement to the subagent layer.

## When to suspend the SOP

See [`session-policy.md`](session-policy.md) §"When to suspend this policy" — emergency bypass rules, policy edits, and the explicit user override.

## The idea in one paragraph

The three persistent sessions keep their context focused on their own surface — docs (Strategist), UI (Designer), dispatch + review coordination (Orchestrator). Heavy thinking about code happens inside bounded peer subagents — Executors write, Reviewers judge, QA verifies — each spun up fresh per gate call. The Orchestrator's context grows with each W-item but only as much as structured verdicts require (not diff content), keeping it bounded. Failed items surface as short "stumped" packages the user can address in one exchange. Successful items surface as merge commits with the Reviewer's verdict + the Executor's lessons-learned notes, landing in `git log` where the user reads them.
