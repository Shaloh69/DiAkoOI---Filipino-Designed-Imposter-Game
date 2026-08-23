# syntax=docker/dockerfile:1

# docker-compose.yml declares `build: ./api`, so this file is load-bearing for
# `docker compose up -d`.
FROM node:22-alpine AS base
ENV PNPM_HOME=/pnpm
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
WORKDIR /app

FROM base AS deps
COPY package.json ./
# --ignore-scripts: the only dev dependency this stage needs is typescript.
# esbuild (pulled in by vitest/tsx) would otherwise want a postinstall, and
# pnpm 11 fails an install outright when a build script is skipped. The image
# never runs tests, so no native binary is needed here.
RUN pnpm install --no-frozen-lockfile --ignore-scripts

FROM deps AS build
COPY tsconfig.json ./
COPY src ./src
RUN pnpm run build

FROM base AS runtime
ENV NODE_ENV=production
COPY package.json ./
# Production deps only — fastify, pg, zod. No build scripts involved.
RUN pnpm install --prod --no-frozen-lockfile --ignore-scripts && pnpm store prune
COPY --from=build /app/dist ./dist
# The .sql migrations are data, not TypeScript, so `tsc` does not carry them
# into dist/. Without this the image starts, finds no schema, and answers 503
# to every documented read — which looks like a database outage and is not.
COPY --from=build /app/src/migrations ./dist/migrations

# Attachments are content-addressed and encrypted at rest (docs/01-DESIGN.md
# §16b). The compose file mounts a volume here.
RUN mkdir -p /app/storage/attachments && chown -R node:node /app/storage
USER node

EXPOSE 3000
CMD ["node", "dist/server.js"]
