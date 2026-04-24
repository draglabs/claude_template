# Stack decisions (undecided — for the Strategist to walk through)

> Status: **undecided**. Every row is a question the Strategist asks the user on first contact. Each resolution becomes an ADR.

## Decision matrix

| Concern | Options | Default if user has no preference | ADR slot |
|---|---|---|---|
| Language + runtime | Node / Python / Go / Bun / Deno / Rust / … | — | `adr-001-language.md` |
| Web framework | Depends on language (Express, FastAPI, Echo, Hono, Axum, …) | Smallest mainstream option for chosen language | `adr-002-framework.md` |
| Database (stub) | SQLite / embedded KV | SQLite (simplest, single-file, no service) | `adr-003-database-stub.md` |
| Database (production) | Postgres / MySQL / managed (Neon, Supabase, …) | Postgres | `adr-004-database-prod.md` |
| Auth mechanism | Cookie-session / signed JWT / OAuth only / Magic link | Cookie-session (simplest mental model, HTTP-only cookies) | `adr-005-auth.md` |
| Password handling | bcrypt / argon2 / scrypt | argon2 (current best-practice default) | `adr-006-password-hashing.md` |
| Frontend | None (API only) / server-rendered / SPA / HTMX | None for stub; revisit at v1 | `adr-007-frontend.md` |
| Container base | alpine / distroless / debian-slim / language-specific official | distroless if compiled language; slim variant for interpreted | `adr-008-container-base.md` |
| Local dev loop | docker-compose / just run + local DB / devcontainer | docker-compose (matches production container model) | `adr-009-dev-loop.md` |
| Deployment target | Fly / Railway / Render / Cloudron / self-host / … | Undecided — not a v0 concern | `adr-010-deployment.md` (later) |
| Dev environment hosting | Local-hosted (Orchestrator helps user set up redirect) / remote-hosted (CI deploys to dev server) | Local-hosted — zero infra cost, fastest iteration. Revisit if multiple contributors or always-on QA is needed. | `adr-011-dev-environment.md` |

## Rules the Strategist uses during the interview

1. **Default only if asked.** The "Default" column is a tiebreaker, not a recommendation. If the user has a preference — any preference — that wins.
2. **Don't railroad related decisions.** Picking Go doesn't force Echo; picking Postgres doesn't force an ORM. Surface each decision as its own ADR.
3. **Stub-only choices are reversible.** SQLite for the stub doesn't commit the project to SQLite for production. The ADR records which decisions are stub-scoped and which are long-term.
4. **One ADR per decision.** Not one giant ADR-001 "the stack" — individual ADRs so future sessions can supersede one without untangling others.
5. **Flag dependencies.** If a decision depends on another (framework depends on language, password hashing depends on auth mechanism), note the dependency in the ADR so the chain is visible.

## When the Strategist can skip the interview

If the user opens their first session with a clear stack declaration ("I want Node + Express + Postgres"), the Strategist writes the ADRs to capture that and moves on to the rest. No need to walk the matrix line-by-line when the user already knows.

## When the decisions get locked

When each ADR hits `Status: accepted`, the one-line summary goes under `## Locked-in decisions` in CLAUDE.md with a link back to the ADR. From that point forward, the decision is not re-litigated without an explicit ADR superseding it.
