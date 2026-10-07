# syntax=docker/dockerfile:1
# Multi-stage build of the site as a Next.js standalone server. Dokploy runs
# the image that GitHub Actions builds from this file.
#
# The base image is spelled out in every FROM line instead of an ARG:
# Dependabot's docker updater does not resolve ARG-based FROM lines.

# --- Shared base: Node.js plus the pinned pnpm ---
FROM node:26.10.0-slim AS base
# Node.js >= 25 no longer bundles Corepack, so install it from npm. Corepack
# then provides exactly the pnpm version pinned in package.json's
# `packageManager`, keeping that field the single source of truth.
ENV PNPM_HOME="/pnpm" \
    PATH="/pnpm:$PATH" \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    NEXT_TELEMETRY_DISABLED=1
RUN npm install -g corepack@latest && corepack enable
WORKDIR /app

# --- Dependencies ---
# Only the manifests, so this layer is rebuilt only when dependencies change.
# pnpm-workspace.yaml carries allowBuilds, which must match local installs.
FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# --- Build ---
FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

# --- Runtime image ---
FROM node:26.10.0-slim AS runner
# HOSTNAME must be set explicitly: Docker injects the container id as
# HOSTNAME, and the standalone server would bind to that instead of all
# interfaces.
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    NEXT_TELEMETRY_DISABLED=1
WORKDIR /app

# The standalone server serves public/ and .next/static only when they sit
# next to server.js; Next.js leaves copying them to us.
COPY --from=build --chown=node:node /app/public ./public
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static

# The official image ships the unprivileged `node` user; never run as root.
USER node
EXPOSE 3000

# The slim image has no curl, so probe /health with Node's built-in fetch.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
