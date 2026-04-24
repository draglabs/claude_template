# ADR-000: Starter stub

**Status:** stub — superseded incrementally by ADR-001 through ADR-00N as the stack is decided
**Date:** 2026-04-23
**Deciders:** David (template author)

## Context

A fresh project using this template needs somewhere concrete for the Strategist (Architect) to orient on when first spun up. An empty `docs/architecture/` folder gives the Strategist nothing to react to — they'd have to drive the user through an abstract blank-page interview before any planning can happen.

At the same time, pre-picking a stack (Node + Express + Postgres, say) would railroad the user's decisions by making a preliminary choice sticky.

## Decision

Ship a *shape*, not a *stack*.

The starter architecture describes:
- A single containerized HTTP service.
- Two routes: `/` (hello world) and `/login` (session-based auth).
- A minimal `users` table.
- Every stack-level decision (language, framework, database, auth mechanism, …) explicitly flagged **undecided** in [`stack.md`](stack.md), with a decision matrix the Strategist walks through with the user.

The shape is fixed enough that the Strategist has a concrete target to reason about. The stack is open enough that the user makes the real calls.

## Consequences

**What this buys:**
- Strategist has somewhere to start on first contact. The opening move is "walk through `stack.md` and record each answer as an ADR."
- First Orchestrator session, once ADRs 001-NN are accepted, dispatches a W-item to scaffold the stub in the chosen stack. Acceptance criteria are listed in `system-overview.md` §"Artifacts the stub implies."
- The architecture surface is populated from day one — no empty folders for the Strategist to audit.

**What this costs:**
- Three stub docs (`system-overview.md`, `stack.md`, `data-model.md`) that get overwritten once the stack solidifies. Acceptable — they're short and they're fulfilling their purpose by getting overwritten.
- A small risk of the stub biasing the user toward its defaults (cookie-session, SQLite-for-stub, argon2). Mitigation: every default is clearly labeled "default if user has no preference" in `stack.md`, not "our recommendation."

## Alternatives considered

1. **Empty `docs/architecture/` folder.** Rejected — leaves the Strategist with no orientation, forces an abstract interview.
2. **Fully-specified reference stack (Node + Express + Postgres).** Rejected — railroads user decisions; turns template into opinionated framework.
3. **A single TODO.md listing decisions to make.** Rejected — not structured enough; the decision matrix is more useful than a flat list.

## Supersession plan

This ADR does NOT get superseded wholesale. It's the explanation of why the stub exists. Each stack decision supersedes its matching row in `stack.md` individually via its own ADR. When all ten rows in `stack.md` have been resolved into ADRs and the actual scaffolding W-item has shipped, this ADR flips to `Status: accepted (historical — stub is gone)` and stays as a record of how the project started.
