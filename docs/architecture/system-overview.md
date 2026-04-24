# System overview (stub)

> Status: **stub**. This describes the starter shape, not a committed design. First ADR (`adr-001-stack.md`) supersedes the stack placeholders below.

## Shape

A single containerized HTTP service with two routes. That's it — the minimum viable target for the dev_framework to have something to ship.

```
┌─────────────────────────────────────────┐
│  Docker container                       │
│  ┌───────────────────────────────────┐  │
│  │  HTTP app (stack TBD)             │  │
│  │                                   │  │
│  │   GET /         → "hello world"   │  │
│  │   POST /login   → session cookie  │  │
│  │   GET /me       → requires session│  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Data store (TBD — likely SQLite  │  │
│  │  for stub, Postgres for v1)       │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## What's fixed in the stub

- Runs in a Docker container.
- Exposes HTTP on a single port.
- Has a login route.
- Has a hello-world route.
- Has a minimal user-store of some kind.

## What's undecided (become ADR-001…N)

- Language + runtime (Node / Python / Go / Bun / …)
- Web framework (the usual suspects for whichever language)
- Database (SQLite for stub simplicity → Postgres for production?)
- Auth mechanism (cookie-session / signed JWT / OAuth only / …)
- Frontend (none for stub; SPA or server-rendered for v1?)
- Deployment target (local Docker only for stub; host choice for production)

See [`stack.md`](stack.md) for the decision matrix.

## Artifacts the stub implies

When the first Executor ships the stub, it should produce:

- `Dockerfile` at repo root (or `docker/Dockerfile` if the project prefers).
- `docker-compose.yml` for local dev loop (app + DB container).
- Source tree appropriate to chosen stack.
- Entry point that binds to `0.0.0.0:$PORT` (no hardcoded port — env var).
- `.env.example` with every required env var documented.
- Migration setup (even if the first migration is `CREATE TABLE users`).
- A smoke-test script that hits `/` and expects "hello world".

These become the acceptance criteria for `W-001: scaffold stub` (or whatever the first W-item ends up being named).

## What this is NOT

- Not a production design. It's a place to start.
- Not opinionated about the stack. The Strategist interviews the user to decide.
- Not a reference architecture. It's a runnable skeleton.
