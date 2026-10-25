  # AGENTS.md

## Repository and branch

This repository is **K-Tech's fork of [Docmost](https://github.com/docmost/docmost)**
(`origin` = `github.com/k-tech-italy/docmost`). It exists to add **OIDC single
sign-on (Keycloak)** to the open-source edition, plus K-Tech's Docker build
tooling.

- **This branch, `kt/sso3`,** is upstream v0.97.0 plus the fork commits. Fork
  releases are tagged with the upstream version plus `b` (`v0.97.0b`).
- **`main`** mirrors upstream unchanged and is updated by fast-forward only.
  Never commit fork work there.
- **Each upstream upgrade gets a new branch** (`kt/sso2`, `kt/sso3`, ...),
  re-created from `main`. **`KT_SSO_UPGRADE.md`** is the runbook for creating
  the next one; follow it.
- `git diff main...HEAD` shows the complete fork. Keep it small: add fork lines
  to upstream's code; never reformat upstream files.

## Fork changes

### OIDC SSO

The Keycloak connection (issuer URL, client ID and secret, button name, JIT
flag) is stored per workspace in `workspaces.oidc_*`. An admin or owner edits it
in **Settings → "KT/SW SSO"** (`/settings/security2`). The IdP logout URL is
global and comes from the **`OIDC_LOGOUT_URL`** env var; the "SSO Logout" menu
item is hidden when it isn't set.

| Area | Files |
|------|-------|
| Migration | `apps/server/src/database/migrations/20250222T115000-AddWorkspaceOIDCConfiguration.ts`. **Never rename it**: production databases have it recorded under this name |
| DB types / repos | `database/types/db.d.ts` (hand-added OIDC fields), `database/repos/workspace/workspace.repo.ts`, `database/repos/user/user.repo.ts` (random placeholder password for SSO users) |
| Server endpoints | `core/auth/auth.controller.ts`: `GET /api/auth/oauth-redirect`, `GET /api/auth/cb`, `GET oidc-public-config`, `GET\|PATCH oidc-config`, `GET\|PATCH approved-domains` |
| Server logic | `core/auth/services/auth.service.ts` (`oidcLogin`, `updateOidcConfig`, `updateApprovedDomains`), `core/auth/dto/{oidc-config,update-oidc,update-domains}.dto.ts` |
| `OIDC_LOGOUT_URL` | `integrations/environment/environment.{service,validation}.ts`, `integrations/static/static.module.ts` (`window.CONFIG`), `apps/client/vite.config.ts`, `apps/client/src/lib/config.ts`, `.env.example` |
| Client | `App.tsx` (`security2` route), `components/settings/settings-sidebar.tsx`, `features/auth/components/login-form.tsx` (SSO button), `features/auth/hooks/use-auth.ts` (`logoutSso`), `components/layouts/global/top-menu.tsx`, `pages/settings/workspace/workspace-security.tsx`, `features/workspace/components/settings/components/workspace-security-form.tsx` |
| Tests | `apps/server/package.json`: Jest transforms `openid-client`, `oauth4webapi` and `jose` (ESM-only) |

Known quirks. Keep them, or change them deliberately and say so:

- **JIT is always on:** the `oidcJitEnabled` check in `oidcLogin` is commented
  out, so any IdP user whose email domain is approved is created as `MEMBER`.
- **`oidcEnabled` isn't checked on the server,** and the "Login with KT/SW SSO"
  button is always shown.
- **SSO login skips upstream's MFA check:** `/api/auth/cb` sets the session cookie directly.
- **Fork UI strings are hardcoded English** (no `t()`).
- **`db.d.ts` was edited by hand.** Running `migration:codegen` on a migrated
  database keeps the fields; on an unmigrated one it drops them.

### Docker build (`ktdocker/`)

- `make -C ktdocker build [VERSION=vX.Y.Zb]` builds
  `docker.k-tech.it/kt/docmost:<version>`. The default version is the latest
  reachable git tag; upstream tags are often missing from this clone, so tag
  first or pass `VERSION`.
- `make -C ktdocker run` runs it locally. It needs the `DOCMOST_*` env vars;
  `DOCMOST_OIDC_LOGOUT_URL` is optional.
- `make -C ktdocker release` pushes `<version>` and `latest`. **Only with the
  user's approval.**
- `.reset-storage` restores the DB and storage from a backup and is
  **destructive**.
- The container runs pending migrations on startup (`NODE_ENV=production`).

## Project overview

Docmost is a collaborative wiki and documentation tool: a pnpm + Nx monorepo.
The core is AGPL-3.0; code under `ee/` directories is under the enterprise licence.

| Layer | Stack |
|-------|-------|
| Client (`apps/client`) | React 19, Vite 8, Mantine 9, TanStack Query 5, Jotai, React Router 7, i18next, Vitest |
| Server (`apps/server`) | NestJS 11 on Fastify, Socket.IO, BullMQ, Jest |
| Editor / collab | TipTap 3 (ProseMirror), Yjs, Hocuspocus 4 |
| Data | PostgreSQL via Kysely (query builder + migrations), Redis |
| Storage / mail | Local, S3 or Azure Blob; SMTP or Postmark |
| Runtime | Node 26 (see `Dockerfile`), pnpm 11 (`packageManager`) |

## Layout

```
apps/
  client/src/
    features/      # feature modules (auth, editor, page, space, integration, ...)
    components/ hooks/ lib/ pages/
    ee/            # enterprise UI (AI, bases, SSO, SCIM, MFA, audit, ...)
    App.tsx        # routes
  client/public/locales/   # i18n JSON
  server/src/
    core/          # domain modules: auth, page, space, user, group, comment,
                   #   casl (permissions), search, share, integration, ...
    integrations/  # infrastructure: storage, mail, queue, redis, export, import,
                   #   telemetry, security, outbound (SSRF guard), environment
    collaboration/ # Hocuspocus/Yjs; server/collab-main.ts is the standalone collab server
    database/      # migrations/, repos/, types/db.d.ts (generated)
    ws/            # Socket.IO gateway
    ee/            # enterprise server: a git submodule (docmost/ee), usually empty
packages/
  editor-ext/      # custom TipTap extensions shared by client and server
  base-formula/    # formula engine for "Bases" (database-style tables)
  ee/              # enterprise licence
```

Path aliases:
- Client: `@/` points to `apps/client/src`.
- Server: `@docmost/db/*`, `@docmost/transactional/*`, `@docmost/ee/*` and
  `@docmost/base-formula/{server,client}`.

## Commands

Copy `.env.example` to `.env`; it needs at least `APP_URL`, `APP_SECRET` (32+
chars), `DATABASE_URL` and `REDIS_URL`.

```bash
pnpm install
pnpm editor-ext:build                          # required before client dev/build
pnpm dev                                       # client + server
pnpm build                                     # all projects (Nx)
pnpm collab:dev                                # standalone collaboration server (after build)

pnpm --filter ./apps/server migration:latest   # apply migrations
pnpm --filter ./apps/server migration:create <Name>
pnpm --filter ./apps/server migration:codegen  # regenerate db.d.ts from the live DB

pnpm --filter ./apps/server test               # Jest (*.spec.ts, colocated)
pnpm --filter ./apps/server test:e2e           # apps/server/test
pnpm --filter ./apps/client test               # Vitest (*.test.ts[x])
pnpm --filter ./apps/server lint               # eslint --fix
pnpm --filter ./apps/client lint
```

## Conventions

- **Migrations:** Kysely files in `apps/server/src/database/migrations/` named
  `YYYYMMDDTHHMMSS-name.ts`. After adding one, run it and then `migration:codegen`;
  don't hand-edit `db.d.ts`.
- **Data access:** through repos in `apps/server/src/database/repos/`, not raw
  Kysely in services.
- **Permissions:** CASL abilities in `apps/server/src/core/casl/`.
- **UI strings:** wrap them in `t()` and add the keys to
  `apps/client/public/locales/en-US/translation.json`.
- **Editor nodes:** a new node usually needs an extension in `packages/editor-ext`
  plus a React view under `apps/client/src/features/editor/`.
- **Enterprise code:** feature checks go through `apps/client/src/ee/` (`useHasFeature`)
  and the server licence service. Don't bypass them; `kt/sso2`'s licence bypass
  was dropped on purpose.
- **Outbound HTTP:** `CALLS.md` lists every outbound HTTP call (server, client
  and fork SSO),
  with its location, destination and how to turn it off. Read it before adding
  or changing an external call, and update it in the same change. Server-side
  calls should use `proxyFetch` (`apps/server/src/common/proxy-fetch.ts`) so they
  respect `HTTP(S)_PROXY`.
- Never commit `.env`, `.env.*` or local data folders. `data/` is gitignored, but
  the local `.mount/`, `~storage/` and `.agents/` folders are not ignored, so
  don't `git add -A`.
