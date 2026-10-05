# GoTreat Website

The official website and landing page of GoTreat ([gotreat.de](https://gotreat.de)).

This is a private, proprietary repository. Do not treat it like an open-source
project: no public contribution files, no license headers, and never paste code,
content, or internal details into external services unless asked.

"The maintainer" means the repository owner listed in `.github/CODEOWNERS`.
Everyone with access to this repository is trusted; no identity checks needed.

## Language

- **User-facing content is German.** Page copy, metadata, `alt` texts, and
  everything else visitors see. Write natural German with correct umlauts and
  `ß`, never ASCII substitutes like `ae` or `ss`.
  - Address visitors formally with „Sie“.
  - Gender with a colon (`Kund:innen`) or use neutral wording
    (`Teilnehmende`).
  - German typography: „…“ quotes, en dash `–` for ranges and breaks, and a
    non-breaking space between numbers and units (`10 €`, `5 km`).
  - The brand is always written `GoTreat`.
- **Everything developer-facing is English.** Identifiers, code comments,
  commit messages, branch names, pull requests, and docs (including `docs/`),
  unless explicitly asked otherwise.

## Stack

- Next.js 16 (App Router, `src/app/`), React 19, TypeScript (strict)
- Tailwind CSS v4, configured CSS-first in `src/app/globals.css` (there is no
  `tailwind.config.*`)
- ESLint 9 flat config (`eslint.config.mjs`)
- Node.js 26 (`.nvmrc`), pnpm (version pinned via `packageManager` in
  `package.json`)

Next.js 16 differs from older versions. Follow the managed block at the end of
this file and check `node_modules/next/dist/docs/` before relying on memory.

## Commands

```bash
pnpm install   # install dependencies
pnpm dev       # local dev server
pnpm format    # prettier (also sorts Tailwind classes)
pnpm lint      # eslint
pnpm typecheck # generate route types, then tsc --noEmit
pnpm build     # production build
```

Use pnpm only. Never use npm or yarn, and never edit `pnpm-lock.yaml` by hand.
`allowBuilds` in `pnpm-workspace.yaml` controls which dependencies may run
install scripts; ask before changing it.

Formatting is Prettier's job; do not hand-format. Run `pnpm format:check`,
`pnpm lint`, `pnpm typecheck`, and `pnpm build` before committing. Do not
bypass failing checks; fix the failure or explain exactly why it is acceptable.

## Principles

- **Server Components by default.** Add `"use client"` only where interactivity
  requires it, and push it down to the smallest leaf component.
- **Static first.** The site is a landing page. Pages should render statically
  unless there is a concrete reason for dynamic rendering.
- **Use the framework.** `next/image` for images, `next/font` for fonts, the
  Metadata API for titles, descriptions, and Open Graph data.
- **Desktop first, mobile complete.** Design for desktop first, but every page
  must work fully on mobile. Lint and build do not catch visual issues: check
  UI changes in `pnpm dev` at desktop and mobile widths.
- **Performance and accessibility are features.** Semantic HTML, meaningful
  `alt` texts, keyboard navigation, sufficient contrast, and good Core Web
  Vitals are part of done, not polish.
- **Reuse before inventing.** Follow existing components, spacing, and
  typography instead of creating one-off styles.
- **No dependencies without a reason.** Check whether Next.js, React, or an
  existing dependency already covers the need first.

## Code Conventions

- Import via the `@/*` alias (maps to `src/*`) instead of deep relative paths.
- File names in kebab-case, React components in PascalCase.
- Named exports, except where Next.js requires a default export (`page`,
  `layout`, `not-found`, etc.).
- No `any`. Use `import type` for type-only imports.

## Legal

The site is operated in Germany and must comply with GDPR and German law.

- No requests to third parties without consent: no external fonts, CDNs,
  embeds (YouTube, Google Maps, social widgets), analytics, or tracking.
  Self-host assets instead; `next/font` already does this for fonts.
- No cookies or local storage beyond what is technically necessary, unless a
  consent solution is in place.
- Impressum and Datenschutzerklärung must stay reachable from every page.
- Never write or change legal texts on your own. Flag when a change (e.g. a
  new form, service, or embed) may require updating them.

## Workflow

- Read-only investigation is always fine.
- All changes go on a branch named `<type>/<short-slug>`
  (e.g. `feat/hero-section`) and through a pull request. The maintainer may
  push to `main` directly; agents never do, unless explicitly asked.
- Never force-push or merge a pull request without explicit approval. The
  maintainer performs the final merge.
- Keep changes focused on the task. Do not refactor or reformat unrelated code.

## Commit Style

Use lowercase [conventional commits](https://www.conventionalcommits.org/),
written in English, imperative mood, no emojis, and no AI co-author lines.

```text
<type>(<optional scope>): <description>
```

Types: `feat`, `fix`, `perf`, `revert`, `style`, `refactor`, `docs`, `test`,
`build`, `ci`, `chore`. Mark breaking changes with `!` (e.g. `feat!: ...`).

```text
feat(hero): add download call to action
fix: correct mobile nav overlap
chore: update next to 16.3.9
```

Keep the subject under 72 characters. Use the body to explain why, not what.

Commit messages on `main` will feed release-please (changelog and version
bump), so pick the type deliberately: `feat`, `fix`, `perf`, and `revert`
appear in the changelog, everything else stays internal. Pull request titles
follow the same format, since they become the commit message on squash merge.

Before committing, propose the commit message and get alignment.

### Signing

All commits and tags must be signed. Each contributor sets up signing in
their own git config (SSH or GPG, e.g. via 1Password), so a plain `git commit`
signs automatically.

- Never disable or bypass signing: no `--no-gpg-sign`, no
  `-c commit.gpgsign=false`, no changes to the signing config.
- If signing is not configured, or fails (e.g. a locked key agent or a pending
  approval prompt), stop and ask the human you are working with to fix it,
  then retry. Never fall back to an unsigned commit.
- Rewriting history (amend, rebase) must keep commits signed.

## Releases

Releases are planned to run through release-please. Until that flow exists and
afterwards: never bump the version, edit `CHANGELOG.md`, or create release tags
by hand. Deployment is not decided yet; do not add deployment config without
being asked.

## Secrets

`.env*` files are gitignored. Never commit secrets, tokens, or API keys, and
never print them in logs or commit messages.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
