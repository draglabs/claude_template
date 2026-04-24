# Data model (stub)

> Status: **stub**. Minimal user store to make login work. Expand once v1 features are scoped.

## Entities

### users

The only table the stub needs.

| Column | Type | Notes |
|---|---|---|
| `id` | primary key (UUID or auto-inc int — decided with stack) | |
| `email` | text, unique, not null | used as the login identifier |
| `password_hash` | text, not null | argon2 by default — see `adr-006-password-hashing.md` |
| `created_at` | timestamp, default now | |
| `updated_at` | timestamp, default now, on-update now | or handled by app layer |

Intentional omissions for the stub:
- No email verification flow.
- No password reset flow.
- No roles / permissions (single-tier access).
- No profile fields beyond email.
- No soft-delete.

Each of those becomes a v1 decision if the product needs it. Don't add them to the stub.

### sessions (implementation varies)

Depends on auth ADR (`adr-005-auth.md`). Three common shapes:

- **DB-backed sessions** (cookie-session default): add a `sessions` table with `id`, `user_id`, `expires_at`, `data` (jsonb). Cookie holds session id.
- **JWT**: no table. Signed token contains user id + expiry. Nothing server-side except the signing key.
- **Magic link**: add a `login_tokens` table with `token`, `user_id`, `expires_at`, `used_at`. Cookie-session on top once claimed.

The stub defaults to DB-backed cookie-session. If auth ADR picks otherwise, update this doc.

## Invariants

- `users.email` is unique and case-insensitive in practice (store lowercased on insert, or use a case-insensitive index — language/DB specific).
- `users.password_hash` is never null and never plaintext. The stub rejects null-hash users as corrupted data rather than allowing passwordless login.
- Sessions expire. No infinite-lifetime tokens.

## What changes at v1

When the product adds features beyond "hello world + login":
- Expand `users` with whatever identity fields the product needs (name, timezone, …).
- Add product tables (one ADR per major entity if they carry architectural weight — e.g. multi-tenant `accounts` table is worth an ADR; a simple `posts` table probably isn't).
- Revisit the session model if the auth surface grows (OAuth providers, API keys, service accounts).

This doc is scoped to the stub. Past the stub, the pattern is: each architectural entity gets its own section here or its own file in `architecture/`.
