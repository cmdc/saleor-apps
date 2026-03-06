FROM node:22-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Prune monorepo to only what the app needs
FROM base AS pruner
WORKDIR /app
COPY . .
ARG APP_NAME
RUN pnpm dlx turbo prune ${APP_NAME} --docker

# Install dependencies on pruned workspace
FROM base AS installer
WORKDIR /app
COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
RUN pnpm install --frozen-lockfile

# Build the app
FROM installer AS builder
WORKDIR /app
COPY --from=pruner /app/out/full/ .
ENV NEXT_TELEMETRY_DISABLED=1
ARG APP_DIR
RUN pnpm --filter "./apps/${APP_DIR}" exec next build

# Production image
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ARG APP_DIR
COPY --from=builder /app .
WORKDIR /app/apps/${APP_DIR}
EXPOSE 3000
CMD ["node_modules/.bin/next", "start", "-p", "3000"]
