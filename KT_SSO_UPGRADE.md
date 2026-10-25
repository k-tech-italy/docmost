# Runbook: create the next `kt/ssoN` branch

Instructions for an AI agent that ports K-Tech's fork changes (OIDC SSO for
Keycloak plus the `ktdocker` build files) onto a new upstream Docmost release.

This file lives on the fork branches, not on `main`. From any checkout, read the
latest copy with `git show <latest kt/sso branch>:KT_SSO_UPGRADE.md`.

## Ground rules

- **Never commit to `main`.** It mirrors upstream and is updated by fast-forward only.
- **Ask the user before anything outward-facing:** pushing a branch, creating or
  pushing a tag, `make -C ktdocker release`, or opening a PR. Local commits on
  the new branch are fine.
- **Port only the fork features listed below.** The space-sharing licence bypass
  from `kt/sso2` (`v0.80.1b`) was dropped on purpose in `kt/sso3`. Don't bring it
  back unless the user asks.
- **Keep the fork diff small:** add fork lines to upstream's version; never
  reformat or restructure upstream code.
- **Report what you couldn't verify**, e.g. no end-to-end Keycloak login.

## What the fork consists of

`git diff main <PREV>` should show only these (as of `kt/sso3`, 27 files):

| Area | Files |
|------|-------|
| DB | `apps/server/src/database/migrations/20250222T115000-AddWorkspaceOIDCConfiguration.ts`, `database/types/db.d.ts` (OIDC fields on `Workspaces`), `database/repos/workspace/workspace.repo.ts` (OIDC columns in the selectable list), `database/repos/user/user.repo.ts` (random placeholder password when none is given) |
| Server auth | `core/auth/auth.controller.ts` (`cb`, `oauth-redirect`, `oidc-public-config`, `oidc-config`, `approved-domains`), `core/auth/services/auth.service.ts` (`oidcLogin`, `updateOidcConfig`, `updateApprovedDomains`, 3 injected deps), `core/auth/dto/{oidc-config,update-oidc,update-domains}.dto.ts` |
| Logout URL setting | `integrations/environment/environment.{service,validation}.ts` (`OIDC_LOGOUT_URL`), `integrations/static/static.module.ts` (exposed in `window.CONFIG`), `apps/client/vite.config.ts` (dev env), `apps/client/src/lib/config.ts` (`getOidcLogoutUrl`), `.env.example` |
| Client | `App.tsx` (lazy `WorkspaceSecuritySettings` + `security2` route), `components/settings/settings-sidebar.tsx` ("KT/SW SSO"), `features/auth/components/login-form.tsx` (SSO button), `features/auth/hooks/use-auth.ts` (`logoutSso`), `components/layouts/global/top-menu.tsx` ("SSO Logout", only shown when the URL is set), `pages/settings/workspace/workspace-security.tsx`, `features/workspace/components/settings/components/workspace-security-form.tsx` |
| Tests | `apps/server/package.json`: Jest `transform` + `transformIgnorePatterns` include `openid-client\|oauth4webapi\|jose` |
| Build | `ktdocker/{Makefile,README.md,docker-compose.yml}`, `.dockerignore` (`~storage`, `.mount`) |
| Docs | this file, plus `AGENTS.md` / `CALLS.md` if they are committed on the fork branch |

## Procedure

### 1. Work out names and check preconditions

```bash
git fetch origin --prune
git status --porcelain | grep -v '^??'           # must be empty
# Highest existing number; plain "kt/sso" counts as 1
git for-each-ref --format='%(refname:short)' refs/heads/kt refs/remotes/origin/kt \
  | sed -nE 's#^(origin/)?kt/sso([0-9]*)$#\2#p' | sed 's/^$/1/' | sort -n | tail -1
```

- `PREV` is `kt/sso<max>` and `NEW` is `kt/sso<max+1>`. Stop if `NEW` already
  exists locally or on `origin`.
- Make sure local `main` matches `origin/main` and is at the release the user
  wants: `git log -1 main` and `git show main:package.json | grep '"version"'`.
  Call that version `X.Y.Z`. Upstream tags are often missing from this clone, so
  trust `package.json`, not `git describe`.
- `BASE=$(git merge-base main PREV)` is the upstream commit `PREV` was built on.
  `git log --oneline BASE..PREV` lists the fork commits to port.
- `PREV_TAG` is the fork tag on `PREV`'s tip (e.g. `v0.97.0b`), if there is one.

### 2. Create the branch and replay the fork commits

```bash
git switch -c "$NEW" main
git cherry-pick BASE..PREV            # keep the commit structure
```

Use cherry-pick from `kt/sso3` onward, since its history is clean (one SSO commit,
one ktdocker commit, possibly a docs commit). Only if a commit turns out to be
unusable, fall back to applying the diff with path exclusions:
`git diff BASE PREV -- <paths> > /tmp/x.diff && git apply --3way /tmp/x.diff`.

### 3. Resolve conflicts

The rule is: **take upstream's version, then add the fork lines back.** Known
hotspots and how they were resolved last time:

- **`App.tsx`:** upstream converts page imports to `lazyWithPrefetch`. Add
  `WorkspaceSecuritySettings` in the same style; keep the `security2` route.
- **`auth.controller.ts`:** fork imports go *above* the class decorators. Keep
  upstream's `@SkipThrottle(...)` exactly.
- **`auth.service.ts` constructor:** keep every upstream dependency and append
  `workspaceRepo` and `workspaceService`. Check `groupUserRepo` isn't injected twice.
- **`use-auth.ts`:** `handleLogoutSso` must mirror upstream's `handleLogout`
  (currently `setCurrentUser(RESET)`, `deleteLocalPageData()`, `logout()`), then
  redirect to `getOidcLogoutUrl()`. If upstream adds cleanup steps to logout,
  copy them.
- **`top-menu.tsx`, `settings-sidebar.tsx`, `static.module.ts`, `vite.config.ts`,
  `environment.*`, `apps/server/package.json` (Jest), `.env.example`,
  `.dockerignore`:** small additive edits; re-add them next to the same anchors
  (`DRAWIO_URL`, `COLLAB_URL`, `happy-dom`).

Then check for **upstream changes the fork code depends on**, even when they
didn't conflict:

- **`openid-client`:** the major version and the APIs used (`discovery`,
  `buildAuthorizationUrl`, `authorizationCodeGrant`, `serverMetadata`, `claims`).
- **Login session:** `SessionService.createSessionAndToken(user)` and
  `AuthController.setAuthCookie(reply, token)` still exist with the same signatures.
- **User creation:** `UserRepo.insertUser`, `WorkspaceService.addUserToWorkspace`
  and `GroupUserRepo.addUserToDefaultGroup`.
- **Name clashes:** upstream adding its own `oidc_*` columns to `workspaces`, or
  its own `/auth/oidc-*`, `/auth/cb` or `/auth/oauth-redirect` routes. If it
  does, **stop and ask the user.**
- **Workspace context:** the `@AuthWorkspace()` decorator still works on
  unauthenticated GET routes.
- **Login flow changes:** e.g. MFA or SSO enforcement. Mention them; don't
  silently bypass them.

### 4. Check that the database will upgrade cleanly

Kysely runs migrations in strict name order and refuses to start if one it
already applied is missing, renamed, or sorts after a pending one.

```bash
M=apps/server/src/database/migrations
git ls-tree --name-only "$PREV_TAG" $M/ | xargs -n1 basename | sort | tail -1   # last applied
git diff --name-status --diff-filter=A  "$PREV_TAG" "$NEW" -- $M   # all must sort after it
git diff --name-status --diff-filter=DRM "$PREV_TAG" "$NEW" -- $M  # must be empty
```

- **Never rename** `20250222T115000-AddWorkspaceOIDCConfiguration.ts`; production
  databases already have it recorded under that name.
- If a new upstream migration sorts *before* the last applied one, or one was
  removed or renamed: **stop and report.** Don't set `allowUnorderedMigrations`
  without the user's approval.
- Scan new `up()` functions for `DROP`, `RENAME`, or index builds on large tables
  (`pages`, `attachments`), and note them for the upgrade report.

### 5. Toolchain and checks

- **Node:** use the version in `Dockerfile` (`FROM node:<v>-slim`); nvm keeps
  versions under `~/.nvm/versions/node/`.
- **pnpm:** use the version in `package.json` `packageManager`.
- **Install:** `CI=true pnpm install --frozen-lockfile`. This replaces
  `node_modules`; tell the user.
- **Build workspace packages first:** `pnpm editor-ext:build`, plus any other
  package the server/client import from source-built `dist` (e.g.
  `packages/base-formula`: `pnpm build`).

**Record a baseline on `main` before judging failures.** Upstream often ships
with known failures; only *new* failures are yours. Run the same checks in a
separate worktree (`git worktree add <scratch dir>/main-wt main`). Don't use
`git stash -u`: it would sweep up the untracked local data folders (`~storage`,
`.mount`).

| Check | Command | Pass criteria |
|-------|---------|---------------|
| Server types | `cd apps/server && npx tsc --noEmit -p tsconfig.json` | No errors beyond the `main` baseline (at v0.97.0: `workspace.service.spec.ts` TS2554) |
| Client types | `cd apps/client && npx tsc --noEmit -p tsconfig.json` | Clean |
| Server tests | `cd apps/server && npx jest src/core/auth src/integrations/environment` | Suites *load* (no ESM/`openid-client` errors). Placeholder "should be defined" DI failures are upstream's |
| Formatting | `npx prettier --check <changed files>` | Only format files that pass Prettier on `main` (`git show main:<f> \| npx prettier --stdin-filepath <f> --check`) plus new files. Never reformat a whole upstream file |
| ESLint | `pnpm --filter ./apps/client lint` | Optional: upstream's local ESLint setup is often broken; note it if skipped |

### 6. Docker image

```bash
make -C ktdocker build VERSION=vX.Y.Zb      # long-running: run it in the background
docker run --rm --entrypoint sh docker.k-tech.it/kt/docmost:vX.Y.Zb -c '
  node -v
  grep -l oauth-redirect /app/apps/server/dist/core/auth/auth.controller.js
  grep -c OIDC_LOGOUT_URL /app/apps/server/dist/integrations/static/static.module.js
  ls /app/apps/server/dist/database/migrations | grep OIDC
  grep -rl "KT/SW SSO" /app/apps/client/dist/assets | head -1
  ls -a /app | grep -E "storage|mount|\.env" || echo clean'
```

The fork version is the upstream version plus `b` (`v0.80.1b`, `v0.97.0b`).
Don't run `make -C ktdocker release` without the user's approval.

### 7. Commit and report

- **Commits:** one per logical change, in the same style as `kt/sso3`:
  `feat(auth): OIDC SSO (Keycloak) on top of vX.Y.Z` and
  `build(ktdocker): ...`. Cherry-picked commits keep their messages; add a
  fix-up commit for port-specific changes, and say in the message what changed
  compared with `PREV`.
- **Docs:** update `AGENTS.md`, `CALLS.md` (if committed on the branch) and this
  runbook with anything new you learned: new hotspots, toolchain changes, new
  baseline failures.
- **Report to the user:**
  - branch name and commit hashes;
  - conflicts and how you resolved them;
  - upstream changes that affect SSO;
  - the migration analysis: list of new migrations, whether any manual step is
    needed, and lock or drop risks;
  - check results compared with the `main` baseline;
  - image tag and ID;
  - what remains: tag (`git tag vX.Y.Zb`), `git push -u origin <NEW>`,
    `git push origin vX.Y.Zb`, `make -C ktdocker release VERSION=vX.Y.Zb`, and
    setting `OIDC_LOGOUT_URL` on the production container.
