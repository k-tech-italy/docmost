# TL;DR

- Installation doc: [Installation](https://docmost.com/docs/installation)

## Compile

```bash
pnpm install
pnpm build
```

## Docker image

The image is tagged with the latest git tag reachable from `HEAD`. Tag the fork
commit before building (e.g. `git tag v0.97.0b`), or override the version:

```bash
make build                   # docker.k-tech.it/kt/docmost:<latest tag>
make build VERSION=v0.97.0b  # explicit version
make release                 # push <version> and latest
```

## Run locally

`make run` needs the `DOCMOST_*` variables checked by the `.guards` target.
Optionally set `DOCMOST_OIDC_LOGOUT_URL` to the Keycloak end-session URL to
enable the "SSO Logout" menu item, e.g.
`https://keycloak.example.com/realms/<realm>/protocol/openid-connect/logout`.
