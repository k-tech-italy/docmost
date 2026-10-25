# External HTTP calls

Inventory of outbound HTTP calls on `kt/sso3`: upstream Docmost v0.97.0
(`e113d652`) plus the K-Tech SSO fork. Paths are relative to the app folder
named in each section. Last reviewed: 2026-10-25.

## Server (`apps/server/src`)

| # | Location | Destination | Purpose | When | Configurable / opt-out |
|---|----------|-------------|---------|------|------------------------|
| 1 | `integrations/telemetry/telemetry.service.ts:75` | `POST https://tel.docmost.com/api/event` | Anonymous usage stats: hashed instance ID, version, and counts of users, pages, spaces and workspaces | Every 24h, production only | `DISABLE_TELEMETRY=true`; off for cloud and non-production |
| 2 | `integrations/security/version.service.ts:14` | `GET https://api.github.com/repos/docmost/docmost/releases/latest` | Checks for a newer Docmost release (shown to admins) | When the version endpoint is called | Not configurable; failures are silently ignored |
| 3 | `core/integration/oauth/oauth.service.ts:906` | `POST` to a provider token URL: `api.figma.com/v1/oauth/token` and `/refresh`, `github.com/login/oauth/access_token`, `api.linear.app/oauth/token` | OAuth code exchange and token refresh for workspace integrations | When a user connects an integration, and on token refresh | Integrations are enabled per provider; uses `proxyFetch` |
| 4 | `core/integration/providers/figma/figma.service.ts:54` | `GET https://api.figma.com/v1/files/{key}/meta` | Fetches Figma file metadata for link unfurling | When a Figma link is pasted or unfurled | Figma integration must be connected |
| 5 | `core/integration/providers/github/github.service.ts:272` | `GET https://api.github.com/repos/...`, or `{INTEGRATION_GITHUB_URL}/api/v3` for GitHub Enterprise | Fetches issue, PR and repo data for unfurling and previews | When a GitHub link is unfurled | `INTEGRATION_GITHUB_URL` for GitHub Enterprise |
| 6 | `core/integration/providers/linear/linear.service.ts:263` | `POST https://api.linear.app/graphql` | Fetches Linear issue data for unfurling | When a Linear link is unfurled | Linear integration must be connected |
| 7 | `integrations/storage/drivers/s3.driver.ts:32,67` | S3 API: AWS or `AWS_S3_ENDPOINT` | Attachment upload, download, delete and presigned URLs (AWS SDK) | Every attachment operation | Only when `STORAGE_DRIVER=s3` |
| 8 | `integrations/storage/drivers/azure.driver.ts:190` | Azure Blob Storage account URL | Same as above, for Azure | Every attachment operation | Only when `STORAGE_DRIVER=azure` |
| 9 | `integrations/mail/drivers/postmark.driver.ts:13` | Postmark API, `api.postmarkapp.com` (SDK) | Sends transactional email | Each email | Only when `MAIL_DRIVER=postmark` |

Notes:

- **Shared helpers:** rows 3–6 go through `common/proxy-fetch.ts`, which uses
  `HTTP(S)_PROXY`/`NO_PROXY` if set. Rows 4–6 also go through
  `core/integration/utils/provider-fetch.ts`, which applies a timeout and a capped
  response size, and refuses redirects so a provider can't bounce a request to an
  internal address.
- **SSRF guard:** `integrations/outbound/outbound-agent.factory.ts` and
  `outbound-url.guard.ts` block requests to private addresses. They are exported,
  but nothing in the open-source code uses them; the users are probably in the
  enterprise server code (the `apps/server/src/ee` submodule), which is not
  initialised in this checkout.
- **Gotenberg (PDF export):** `GOTENBERG_URL` is read in
  `integrations/environment/environment.service.ts:78`, but no open-source code
  calls it. The PDF export caller is in the missing enterprise code.
- **Not HTTP, listed for completeness:** SMTP via nodemailer
  (`integrations/mail/drivers/smtp.driver.ts:14`), Postgres, and Redis (BullMQ,
  Socket.IO, Hocuspocus).

## Client (`apps/client/src`, runs in the user's browser)

| # | Location | Destination | Purpose |
|---|----------|-------------|---------|
| 10 | `lib/api-client.ts:5` (axios) and the `ee/ai*` / `ee/pdf-export` `fetch` calls | Same origin, `/api/*` | All app API traffic; internal |
| 11 | `lib/config.ts:92` → Draw.io editor iframe | `https://embed.diagrams.net`, or `DRAWIO_URL` | Hosted Draw.io diagram editor. The default is an external third party; set `DRAWIO_URL` to self-host |
| 12 | `features/editor/components/drawio/drawio-menu.tsx:224`, `features/editor/components/excalidraw/excalidraw-menu.tsx:178` | The attachment's file URL, usually same origin | Loads an existing diagram file into the editor |
| 13 | `features/editor/components/excalidraw/excalidraw-view.tsx:93`, `features/editor/components/excalidraw/excalidraw-menu.tsx:221` | `https://unpkg.com/@excalidraw/excalidraw@latest` | Font URL written into saved Excalidraw SVGs, so viewers fetch fonts from unpkg when the SVG renders |
| 14 | `features/editor/components/common/editor-paste-handler.tsx:271` | The `src`/`url` of pasted nodes, which can be external | Downloads pasted images and files so they can be re-uploaded as local attachments |

Embeds such as YouTube, Loom and Miro are iframes the browser loads from the
provider. They aren't API calls, so they are not listed.

## Fork only (K-Tech OIDC SSO)

| # | Location | Destination | Purpose | Configurable |
|---|----------|-------------|---------|--------------|
| 15 | `apps/server/src/core/auth/auth.controller.ts:86`, `oauthRedirect` (`discovery`) | `GET {workspace.oidcIssuerUrl}/.well-known/openid-configuration` | OIDC discovery before redirecting the user to Keycloak | Issuer per workspace (Settings → "KT/SW SSO") |
| 16 | `apps/server/src/core/auth/services/auth.service.ts:160,174`, `oidcLogin` (`discovery` + `authorizationCodeGrant`) | Issuer discovery document, then `POST` to the issuer's token endpoint | Exchanges the authorisation code for tokens on `/api/auth/cb` | Same as above; the client secret is stored per workspace |
| 17 | `apps/client/src/features/auth/hooks/use-auth.ts:174`, `handleLogoutSso` (browser redirect) | `OIDC_LOGOUT_URL`, e.g. `https://<keycloak>/realms/<realm>/protocol/openid-connect/logout` | SSO logout at the identity provider | `OIDC_LOGOUT_URL` env var; menu item hidden when unset |

Unlike the upstream integration calls, rows 15–16 call `openid-client` directly.
They don't go through `proxyFetch`, so they ignore `HTTP(S)_PROXY` and have no
SSRF guard; the issuer URL is admin-controlled.

## Keeping this file current

Line numbers drift when upstream changes. To re-check, search the source
(excluding `node_modules`, `dist` and tests) for `fetch(`, `proxyFetch`,
`providerApiFetch`, `axios`, `undici`, SDK client constructors (`new S3Client`,
`new BlobServiceClient`, `new ServerClient`, `openid-client`) and hardcoded
`https://` URLs.
