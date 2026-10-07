# Spec: Release flow (release-please, image build in GitHub Actions, deploy to Dokploy)

> Status: Decided 2026-10-07, implementation in progress. P0 lands in two PRs (`feat/container-image`,
> `ci/release-flow`); the first release through the flow is `v0.1.0`, deployed straight to `gotreat.de`. The DNS
> cutover from Hostinger hosting to the VPS is therefore part of the first release (P0-4), not a later step.
> This spec is also the decision record: _Decided defaults_, _Verified behavior_ and _Trade-offs accepted_ carry
> the why. It adopts the platform contract of the skill-platform
> ([skillforge `release-flow.md`][skillforge-spec]) and deviates only where this repo differs.
> Preview deployments per pull request are deferred; their design lives in [#6][preview-issue].

## Problem statement

The website has no release flow. `main` carries a CI job (`check`), a ruleset and conventional commits that
already assume release-please (Dependabot prefixes `fix(deps)` / `chore(deps-dev)`), but nothing turns a merge
into a version, a changelog, an image or a deployment. `gotreat.de` is still served by Hostinger hosting behind
its CDN; the Dokploy instance that hosts the maintainer's other projects (https://vps.leonweimann.de) has no
website service yet.

## Goals

1. **Same flow as skillsite.** Same workflow file names, job names, config files, variable and secret names.
   Knowing how skillsite releases means knowing how the website releases.
2. **Releasing is one deliberate act:** merging the release PR. Version, `CHANGELOG.md`, tag, GitHub release,
   image and deploy follow without further manual steps.
3. **Build in GitHub.** The container image is built and pushed by GitHub Actions. Dokploy only pulls and runs
   it; nothing is built on the VPS.
4. **The deploy reports the truth.** The shared deploy workflow waits for Dokploy and verifies the running
   version through `/health`. A failed deploy is a red workflow run.
5. **First release `v0.1.0`**, matching the version `package.json` already carries.

## Non-goals

- **Preview deployments per pull request.** Designed, deferred, tracked in [#6][preview-issue].
- **A staging environment.** Production only, and no temporary verification host: the first release goes
  straight to `gotreat.de`.
- **Automatic rollback.** Re-dispatch `Deploy` with an earlier version, or fix forward (as in skill-platform).
- **Static export.** `output: "export"` with nginx was considered: smaller image, but a hand-written nginx
  config that must mirror Next.js routing, no `next/image` optimisation, no route handlers (no `/health`).
  The standalone server is the documented path and keeps every feature open.
- **Dokploy's native preview deployments and push-to-deploy.** Both build on the VPS from Dokploy's own GitHub
  App; see _Deferred: preview deployments_.
- **Supply-chain hardening** beyond SHA-pinned actions: no digest pinning, attestations, SBOMs or signed tags.

## Decided defaults

| Topic                            | Decision                                                                                                                                                                                                                                                                                                                                                                  | Rationale                                                                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A - Release mechanism**        | [release-please](https://github.com/googleapis/release-please) via `googleapis/release-please-action` v5, pinned by SHA, manifest config (`release-please-config.json`, `.release-please-manifest.json`), `release-type: node`.                                                                                                                                           | Same tool and config shape as skillsite. Manifest mode is required for `extra-files`, `initial-version` and the pre-1.0 flags.                                                                                                                                                                                                                                                                                  |
| **B - First version**            | Manifest `{".": "0.0.0"}` plus `"initial-version": "0.1.0"`. The first release PR is `chore(main): release 0.1.0`, creates tag `v0.1.0` and a changelog over the whole history.                                                                                                                                                                                           | `package.json` is already at `0.1.0` but no tag exists. A manifest at `0.1.0` would make release-please treat `0.1.0` as released: the first release would be `0.2.0` with a compare link to a tag that does not exist.                                                                                                                                                                                         |
| **C - Pre-1.0 versioning**       | `bump-minor-pre-major: true`, `bump-patch-for-minor-pre-major: false`: `feat` bumps the minor, `fix` the patch, a breaking change stays below `1.0.0`. `1.0.0` is declared deliberately with a `Release-As: 1.0.0` commit footer once the site is complete (legal pages in place).                                                                                        | Nothing is live on the VPS yet; `1.0.0` should mark the launch, not fall out of one `!`.                                                                                                                                                                                                                                                                                                                        |
| **D - Changelog**                | `changelog-sections` as in skillsite: `feat`, `fix`, `perf`, `revert` visible; everything else hidden. Dependabot `fix(deps)` bumps keep producing patch releases and changelog lines; `chore(deps-dev)`, `ci(deps)` and `build(deps)` stay internal.                                                                                                                     | Matches the Dependabot prefixes already in `.github/dependabot.yml`; a runtime dependency bump should ship.                                                                                                                                                                                                                                                                                                     |
| **E - Release PR author**        | A new GitHub App **`gotreat-automation`** owned by the gotreat-de org, installed on this repository only. release-please runs with its installation token (`actions/create-github-app-token`). The App is general-purpose: release-please now, triage and other automation later.                                                                                         | PRs opened with `GITHUB_TOKEN` never get a workflow run, so the required check `check` would never report; and the `main` ruleset requires signed commits, which GitHub grants to REST-created commits only when authenticated as an App. The skill-platform App cannot be reused without making it public and copying its key anyway.                                                                          |
| **F - App credential names**     | Org-level variable `RELEASE_APP_CLIENT_ID` and org-level secret `RELEASE_APP_PRIVATE_KEY` (selected repositories), despite the App's general name.                                                                                                                                                                                                                        | The shared `skill-platform-workflows` callers (`triage.yml`, and the conventions around `deploy.yml`) read exactly these names. Keeping them means a later triage adoption is a copy of the caller, not a rename.                                                                                                                                                                                               |
| **G - Signatures**               | Feature commits are GitHub-signed by the squash merge. The release commit is created through the REST API as the App and shows as _Verified_ (bot signature). Release tags are lightweight: the Releases API creates them without a tag object. `AGENTS.md` records this exception to "all commits and tags must be signed".                                              | Satisfies the ruleset (`required_signatures` checks commits, the tag ruleset only forbids deletion and update).                                                                                                                                                                                                                                                                                                 |
| **H - Image**                    | Multi-stage `Dockerfile`, `output: "standalone"`, `node:26.x.y-slim` base written literally in every `FROM` line, pnpm from the `packageManager` pin, non-root user, `HOSTNAME=0.0.0.0`, `PORT=3000`, `HEALTHCHECK` through `node -e fetch(...)`. Built by `build.yml` (`workflow_call` + `workflow_dispatch`), `linux/amd64`, `provenance: false`, cache `type=gha`.     | Standalone keeps every Next.js feature and mirrors skillsite's image. `HOSTNAME` must be explicit because Docker injects the container id and Next's `server.js` binds to it. Dependabot's docker parser only matches literal `FROM image:tag` lines, never `FROM node:${ARG}`. `provenance: false` avoids untagged attestation manifests in the package.                                                       |
| **I - Image tags**               | `ghcr.io/gotreat-de/website:vX.Y.Z` (the `v` kept so tag, image and compose pin read the same), `:sha-<12>`, `:latest`. Nothing deploys from `latest`.                                                                                                                                                                                                                    | Same scheme as skillsite.                                                                                                                                                                                                                                                                                                                                                                                       |
| **J - Package visibility**       | The GHCR package `website` is switched to **public** once after the first push (irreversible).                                                                                                                                                                                                                                                                            | The repository is public; a public package lets Dokploy pull anonymously, so no registry credential is stored in Dokploy.                                                                                                                                                                                                                                                                                       |
| **K - Deploy transport**         | The org's own reusable workflow `gotreat-de/.github/.github/workflows/deploy.yml`, a copy of the skill-platform one, called from this repo's thin `deploy.yml` and pinned by commit SHA with a version comment like every other action: `compose.update` with the released `compose.yml` (raw), `compose.deploy`, poll `deployment.allByCompose`, poll `HEALTH_URL`.      | No dependency on another org: the maintainer owns both repos. The only code that talks to Dokploy lives in one place with its tests; Dependabot's github-actions group bumps the pin when `.github` tags a new version, and rolling a caller back is pinning the earlier SHA.                                                                                                                                   |
| **L - Dokploy service model**    | A Dokploy **organization for GoTreat** (exists, created by the maintainer), project `gotreat-website`, environment `production`, **compose** service `website` (`sourceType: raw`). `compose.yml` in the repo root pins `image: ghcr.io/gotreat-de/website:vX.Y.Z # x-release-please-version`; release-please moves the pin in the release commit (`generic` extra-file). | Uniform with skillsite; `main` records what production runs; Dokploy runs the compose it stores, so every deploy stores the released file first. The separate organization scopes the API key: it cannot reach the skill-platform projects.                                                                                                                                                                     |
| **M - Health contract**          | `GET /health` answers `{"status":"ok","version":"X.Y.Z"}` with the version from `package.json`, `export const dynamic = "force-static"`, `Cache-Control: no-store`.                                                                                                                                                                                                       | The shared deploy script parses the body with `jq` (`.status == "ok" and .version == $version`), so extra fields would not break it; the contract stays at exactly these two fields anyway. release-please bumps `package.json`, so the version in the image is correct by construction.                                                                                                                        |
| **N - Configuration placement**  | Org-level variable `RELEASE_APP_CLIENT_ID` and org-level secret `RELEASE_APP_PRIVATE_KEY` (one App, one key for every repo that adopts it); repository variable `DOKPLOY_BASE_URL`; environment `production` (deployment branches: `main`) with secret `DOKPLOY_API_KEY` and variables `DOKPLOY_COMPOSE_ID`, `HEALTH_URL`.                                                | `vars.DOKPLOY_BASE_URL` in the shared workflow resolves against the _calling_ repo and org; the Nachhilfe org variable does not reach gotreat-de. The App credentials live once at org level, as in skill-platform, so a key rotation is one change. Caveat: on the Free plan org variables and secrets do not reach private repos; if this repo ever becomes private, they must be copied to repository level. |
| **O - Migration**                | No temporary host: the Dokploy service carries `gotreat.de` and `www.gotreat.de` from the start, and DNS moves to the VPS right before the first deploy.                                                                                                                                                                                                                  | The maintainer wants the site on `gotreat.de` directly. Dokploy's Traefik issues certificates with HTTP-01 only, so DNS must point at the VPS before the certificate and the deploy's health check can succeed; a deploy that runs earlier is red and is re-dispatched after the cutover.                                                                                                                       |
| **P - Dependabot for the image** | `package-ecosystem: docker`, weekly, commit prefix `build` with scope; Node majors ignored (the major follows `.nvmrc`).                                                                                                                                                                                                                                                  | A base-image patch rides along with the next release instead of forcing one.                                                                                                                                                                                                                                                                                                                                    |

## Verified behavior

Verified on 2026-10-07 against primary sources (release-please and Dokploy source, GitHub docs, Let's Encrypt
docs) and against this repository's settings through the GitHub API. The skill-platform probes from
[skillforge `release-flow.md`][skillforge-spec] (fast-forward merges, outputs driving follow-up jobs, bot-signed
release commits, `generic` updater on `compose.yml`, cross-repo environment resolution, "Dokploy runs the compose
it stores") are reused, not repeated.

| Question                                | Result                                                                                                                                                                                                                                                                                                                               |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Current release-please action           | `googleapis/release-please-action` v5.0.0 (`45996ed1f6d02564a971a2fa1b5860e934307cf7`, bundles release-please 17.6.0). The `node` strategy updates `package.json` and `CHANGELOG.md`; it never touches `pnpm-lock.yaml` (no root version in it) and skips the absent `package-lock.json` with a warning.                             |
| `initial-version` with manifest `0.0.0` | Produces a first release `0.1.0` (traced in the manifest releaser source of 17.6.0; not yet executed on this repo).                                                                                                                                                                                                                  |
| `generic` updater on a YAML line        | Replaces the first `x.y.z` on every line carrying `x-release-please-version` and keeps a leading `v`. The entry must say `"type": "generic"`: a bare `.yml` path selects the JSONPath YAML updater, which does nothing here.                                                                                                         |
| PRs opened with `GITHUB_TOKEN`          | Never start workflow runs (GitHub docs). The required check `check` would stay pending; hence decision E.                                                                                                                                                                                                                            |
| Repository ruleset `main`               | Squash merge only, required check `check`, required signatures, linear history, no force push, code-owner review, `require_extra_approval_for_unattributed_changes` enabled. Tag ruleset: no deletion, no update. Repo settings: auto-merge on, delete branch on merge on, squash title from PR title.                               |
| Repository visibility and plan          | The repository is **public**; the org is on the Free plan. Actions minutes are free, environments are available, org variables would work (not used, decision N).                                                                                                                                                                    |
| Shared deploy workflow                  | Its job declares `environment: production` and the concurrency group `deploy-production`; it reads `compose.yml` of the released commit through the GitHub API with the caller's token and requires an `image:` line tagged `v<version>`. Health check: `jq` on the JSON body.                                                       |
| Dokploy and Traefik                     | Dokploy ships Traefik with one certificate resolver (`letsencrypt`, HTTP-01 on port 80). A domain added to a compose service becomes a Traefik router with that resolver. Dokploy appends a random suffix to `appName`; the compose id comes from the UI or `project.one`. Environments inside projects exist since Dokploy v0.25.0. |
| DNS today                               | `gotreat.de` nameservers are Hostinger (`dns-parking.com`); `@` and `www` resolve to Hostinger's CDN (`server: hcdn`), no AAAA/wildcard records of relevance. `vps.leonweimann.de` resolves to `72.62.36.31`.                                                                                                                        |
| Corepack on Node 26                     | Not shipped with Node 25 and later; the `Dockerfile` installs it (or pnpm) explicitly.                                                                                                                                                                                                                                               |

Unverified until the first release or a manual check, listed so nobody mistakes them for proven:

- **Bot signing on this repo.** GitHub signs REST-created commits of an App installation; whether the release PR
  passes `required_signatures` _and_ `require_extra_approval_for_unattributed_changes` here is proven by the
  first release PR. Fallback: add the App as a bypass actor of the `main` ruleset for the release branch.
- **Dokploy version on the instance** (environments need >= 0.25.0) and that the Let's Encrypt email in
  _Web Server_ is a real address.
- **Hostinger hPanel**: that the CDN can be switched off per domain before the A records are changed; whether a
  third-level wildcard (`*.preview`) is accepted matters only for [#6][preview-issue].
- **The Vercel GitHub App** installed on the gotreat-de org: whether a Vercel project is linked to this repo and
  builds PRs in parallel. To be decided by the maintainer (uninstall or exclude the repo).
- **Legal pages.** `src/app` has only the layout and the homepage. Impressum and Datenschutzerklärung must exist
  and be linked before `gotreat.de` serves the new site. They are written by the
  maintainer, never by an agent.

## Trade-offs accepted

- **Commit messages are load-bearing.** The PR title becomes the squash commit and drives version and changelog.
- **A second repo to maintain.** The deploy workflow and its script live in `gotreat-de/.github` and are a copy
  of skill-platform-workflows, so fixes made there have to be ported by hand. Accepted: the org must not depend
  on another org's repo, and the script changes rarely.
- **A Dokploy API key in GitHub.** It lives only in the `production` environment, restricted to `main`, and is
  scoped to the GoTreat Dokploy organization.
- **The GHCR package is public, irreversibly.** Consistent with the public repository; nothing in the image is
  not in the repo.
- **Seconds of downtime per production deploy.** A `docker-compose` service is recreated, not rolled. Fine for a
  landing page.
- **The image is built twice per release.** `check` runs `next build` and the `Dockerfile` builds again; the
  Actions cache keeps the second build short, and minutes are free on a public repo.
- **A short outage at cutover.** Between the DNS change and the first successful deploy, `gotreat.de` answers
  from the VPS without the site, and Traefik can only obtain the certificate after DNS points there. Mitigated
  by low TTLs, a quiet hour and doing the cutover right before merging the release PR, not avoided.

## Target shape

```
feature branch -> PR (CI: job "check" green, code-owner review) -> squash merge -> main
                                                            |
                   release.yml: release-please (gotreat-automation token) keeps the release PR current
                                                            |
                              you merge the release PR = the release
                                                            |
       release.yml on that push: tag vX.Y.Z + GitHub release + CHANGELOG.md   (release_created == true)
                                                            |
                    build.yml: image :vX.Y.Z, :sha-<12>, :latest -> ghcr.io/gotreat-de/website
                                                            |
       deploy.yml -> gotreat-de/.github deploy.yml@<sha>: compose.update (released compose.yml)
                     -> compose.deploy -> wait for done/error -> GET /health (status + version)
```

## Contract

- **Workflows:** `ci.yml` (job `check`, unchanged), `release.yml` (push to `main`: job `release-please`, then
  `image` via `build.yml` and `deploy` via `deploy.yml`, both gated on `release_created == 'true'`), `build.yml`
  (`workflow_call` + `workflow_dispatch`: build and optionally push the image for a ref and version), `deploy.yml`
  (`workflow_call` + `workflow_dispatch` with `version` and `dry_run`; calls the shared workflow with
  `secrets: inherit`). The `release-please` job contains nothing after the action, so a failure can never leave
  a release without build and deploy.
- **Files:** `release-please-config.json`, `.release-please-manifest.json`, `CHANGELOG.md` (created by
  release-please, never edited by hand), `compose.yml` (one service `web`, image pinned with
  `# x-release-please-version`, `pull_policy: always`, `restart: unless-stopped`, no ports, no Traefik labels:
  Dokploy injects them from its domain records), `Dockerfile`, `.dockerignore`, `src/app/health/route.ts`,
  `next.config.ts` with `output: "standalone"`.
- **Org-level variable** `RELEASE_APP_CLIENT_ID` and **org-level secret** `RELEASE_APP_PRIVATE_KEY`, granted to selected
  repositories including this one. **Repository variable** `DOKPLOY_BASE_URL` (`https://vps.leonweimann.de`).
- **Environment `production`:** secret `DOKPLOY_API_KEY`; variables `DOKPLOY_COMPOSE_ID`, `HEALTH_URL`
  (`https://gotreat.de/health`). Deployment branches
  restricted to `main`. No required reviewer: merging the release PR is the approval.
- **Image:** `ghcr.io/gotreat-de/website`, tags `vX.Y.Z`, `sha-<12>`, `latest`, `linux/amd64`, public.
- **Merging:** squash via the PR, auto-merge allowed; the PR title is the conventional commit message.
- **Conventions:** every action pinned by full SHA with a version comment, kept current by Dependabot's
  `github-actions` group; `docker` ecosystem for the base image.

## One-time setup (maintainer)

Settings, Apps, Dokploy and DNS are changed by the maintainer, never from a PR.

1. **GitHub App.** Org gotreat-de, _Developer settings → GitHub Apps → New_: name `gotreat-automation`, no
   webhook, repository permissions _Contents: read and write_, _Pull requests: read and write_, _Issues: read
   and write_, _Metadata: read_. Install on `gotreat-de/website` only. Generate a private key. Store the client
   id as org-level variable `RELEASE_APP_CLIENT_ID` and the PEM as org-level secret `RELEASE_APP_PRIVATE_KEY`, both with
   access to selected repositories including this one. _(Done 2026-10-07.)_
2. **Repository variable** `DOKPLOY_BASE_URL=https://vps.leonweimann.de`.
3. **Environment `production`:** deployment branches `main` only; secret `DOKPLOY_API_KEY`; variables
   `DOKPLOY_COMPOSE_ID`, `HEALTH_URL=https://gotreat.de/health`.
4. **Dokploy** (GoTreat organization): check the version (>= 0.25.0) and the Let's Encrypt email under _Web
   Server_. Create project `gotreat-website`; in its `production` environment a compose service `website`,
   source _raw_, with the repo's `compose.yml` pasted once as a placeholder (every deploy overwrites it). Add
   the domains `gotreat.de` and `www.gotreat.de` (service `web`, port 3000, HTTPS, Let's Encrypt). Note the compose id. Create an
   API key under _Settings → Profile → API Keys_ for this organization (rate limiting off, expiry set).
5. **Hostinger DNS cutover**, right before merging the release PR: export the zone, lower the TTL of `@` and
   `www` a day ahead, switch the CDN off in hPanel, set `A @` and `A www` to `72.62.36.31`, remove AAAA records
   unless the VPS has IPv6, leave MX and TXT records untouched. Traefik issues the certificates once the records
   resolve to the VPS.
6. **GHCR:** after the first image push, _Package settings → Change visibility → Public_. Until then the first
   deploy cannot pull; re-dispatch `Deploy` afterwards.
7. **After the first release PR:** confirm its commit shows _Verified_ and `check` ran. If the ruleset still
   blocks it, add the App as a bypass actor for the `main` ruleset.

## Requirements

### Must-have (P0)

**P0-1 - Container image and health contract** (PR `feat: add container image and health endpoint`).

- _Technique:_ `Dockerfile`, `.dockerignore`, `output: "standalone"` in `next.config.ts`, `src/app/health/route.ts`
  (decision M), `compose.yml` with the annotated pin at `v0.1.0`, Dependabot `docker` entry (decision P).
- _Acceptance criteria:_
  - [ ] `docker build` succeeds locally and `docker run -p 3000:3000` answers `GET /health` with
        `{"status":"ok","version":"0.1.0"}`.
  - [ ] `pnpm format:check`, `pnpm lint`, `pnpm typecheck`, `pnpm build` stay green.

**P0-2 - release-please with the gotreat-automation App** (PR `ci: add release flow with release-please`).

- _Technique:_ `release-please-config.json` (decisions A to D, `extra-files` `compose.yml` as `generic`),
  `.release-please-manifest.json` at `0.0.0`, `release.yml` job `release-please` with the App token and nothing
  after the action.
- _Acceptance criteria:_
  - [ ] After the merge, a release PR `chore(main): release 0.1.0` exists whose diff touches exactly
        `package.json` (no-op), `CHANGELOG.md`, `compose.yml` (no-op at `v0.1.0`) and the manifest.
  - [ ] Its head commit is _Verified_ and its `check` run executes and is green.

**P0-3 - Build and deploy hang off `release_created`** (same PR as P0-2).

- _Technique:_ `build.yml` (decision H and I), `deploy.yml` as the thin caller from the `gotreat-de/.github`
  README; `release.yml` chains `release-please` → `image` → `deploy`.
- _Acceptance criteria:_
  - [ ] A push to `main` that is not a release runs release-please only; image and deploy are skipped.
  - [ ] A `dry_run` dispatch of `Deploy` is green against the GoTreat Dokploy compose service.

**P0-4 - First release.**

- _Acceptance criteria:_
  - [ ] Merging the release PR creates tag `v0.1.0`, the GitHub release, the image
        `ghcr.io/gotreat-de/website:v0.1.0` and a green `deploy` job.
  - [ ] DNS for `gotreat.de` and `www.gotreat.de` points at the VPS and Traefik holds certificates for both.
  - [ ] `https://gotreat.de/health` answers `{"status":"ok","version":"0.1.0"}`.

**P0-5 - Docs.** `AGENTS.md` describes the flow (release PR is the release, never bump versions or edit
`CHANGELOG.md` by hand, the signing exception of decision G, `/health` contract) and points here; `README.md`
has a one-line pointer.

- [x] Done in the `ci/release-flow` PR.

### Nice-to-have (P1)

**P1-1 - After the cutover.**

1. Declare `1.0.0` with a `Release-As: 1.0.0` footer on a later merge, once the legal pages exist.
2. Cancel Hostinger hosting (keep the domain and DNS) after checking that mail and the registration do not
   depend on it.

- [ ] Done.

**P1-2 - `www` redirect** to the apex through `redirects()` in `next.config.ts`, once both hosts are live.

### Deferred: preview deployments

Dokploy's native previews are Application-only, tied to Dokploy's GitHub App, and always clone and build the PR
branch on the VPS; prebuilt-image previews are an open request. They contradict "build in GitHub", so previews
will be driven from Actions: one Dokploy application per PR from the `sha-` image under
`pr-<n>.preview.gotreat.de`. The full design, including the API call sequence and the one-time setup, is in
[#6][preview-issue].

## Open questions

- **Legal pages:** who adds Impressum and Datenschutzerklärung, and when; they gate the cutover (P0-4) and every public host.
  The Datenschutzerklärung must name the VPS provider as processor after the cutover.
- **Repository visibility:** `AGENTS.md` calls the repo private and proprietary; it is public. Decision J and N
  assume public. Decide which one is right.
- **Vercel GitHub App** on the org: linked to this repo or not; remove or exclude.
- **Hostinger:** does mail or the domain registration depend on the hosting plan that P1-1 cancels?
- **IPv6:** does the VPS have a public IPv6 address that should get AAAA records?

## Rules for implementing agents

- Follow `AGENTS.md`: English for everything developer-facing, pnpm only, Prettier formats, `pnpm format:check`,
  `pnpm lint`, `pnpm typecheck` and `pnpm build` green before every commit, conventional commits, no co-author
  lines, signed commits.
- Pin every action by full SHA with a version comment and verify the SHA with `git ls-remote` before using it.
- Never print or echo secrets; the Dokploy key is only ever handled by the shared workflow.
- Do not add rollback, digest pinning, attestation or preview logic; they are non-goals or deferred.
- Repository settings, rulesets, the App, Dokploy and DNS are changed by the maintainer; describe the exact
  setting in the PR body instead.
- Tick the acceptance boxes in this file in the PR that fulfils them and update the status line when P0 is done.

[skillforge-spec]: https://github.com/Nachhilfe-Leon-Weimann/skillforge/blob/main/docs/specs/release-flow.md
[preview-issue]: https://github.com/gotreat-de/website/issues/6
