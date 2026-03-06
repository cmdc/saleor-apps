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
# Env vars required by Zod validation at build time (real values injected at runtime)
ARG SECRET_KEY=buildtime_placeholder
ARG REQUEST_SECRET=buildtime_placeholder
ARG DYNAMODB_MAIN_TABLE_NAME=buildtime_placeholder
ARG AWS_REGION=local
ARG AWS_ACCESS_KEY_ID=local
ARG AWS_SECRET_ACCESS_KEY=local
ARG AWS_ENDPOINT_URL=http://localhost:8000
ENV SECRET_KEY=${SECRET_KEY}
ENV REQUEST_SECRET=${REQUEST_SECRET}
ENV DYNAMODB_MAIN_TABLE_NAME=${DYNAMODB_MAIN_TABLE_NAME}
ENV AWS_REGION=${AWS_REGION}
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL}
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
