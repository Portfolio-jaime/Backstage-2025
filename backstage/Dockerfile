# Multi-stage Dockerfile for complete Backstage build
FROM node:22-bookworm-slim AS packages

WORKDIR /app
COPY backstage/package.json backstage/yarn.lock ./
COPY backstage/.yarn ./.yarn
COPY backstage/.yarnrc.yml ./
COPY backstage/backstage.json ./

# Copy package.json files for all packages
COPY backstage/packages packages

# Only copy plugins if it contains actual Backstage plugins with package.json
# For now, skip plugins as they don't follow Backstage plugin structure
# COPY backstage/plugins ./plugins

# Install dependencies
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable

FROM node:22-bookworm-slim AS build

# Set Python interpreter for `node-gyp` to use
ENV PYTHON=/usr/bin/python3

# Install isolate-vm dependencies, these are needed by the @backstage/plugin-scaffolder-backend.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential && \
    rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /app

# Copy packages and dependencies from packages stage
COPY --from=packages --chown=node:node /app /app

# Copy application source
COPY --chown=node:node backstage/app-config*.yaml ./
COPY --chown=node:node backstage/catalog ./catalog
COPY --chown=node:node backstage/examples ./examples

# Build the application
RUN yarn build:backend

FROM node:22-bookworm-slim AS runtime

# Install isolate-vm dependencies, these are needed by the @backstage/plugin-scaffolder-backend.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install sqlite3 dependencies and curl for health checks
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-dev curl && \
    rm -rf /var/lib/apt/lists/*

# From here on we use the least-privileged `node` user to run the backend.
USER node

# This should create the app dir as `node`.
WORKDIR /app

# Copy the install dependencies from the build stage and context
COPY --from=build --chown=node:node /app/yarn.lock /app/package.json /app/packages/backend/dist/bundle.tar.gz ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Copy yarn configuration
COPY --from=build --chown=node:node /app/.yarn ./.yarn
COPY --from=build --chown=node:node /app/.yarnrc.yml ./
COPY --from=build --chown=node:node /app/backstage.json ./

# This switches many Node.js dependencies to production mode.
ENV NODE_ENV=production

# This disables node snapshot for Node 20+ to work with the Scaffolder
ENV NODE_OPTIONS="--no-node-snapshot"

# Install only production dependencies
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

# Copy any other files that the backend needs to run.
COPY --from=build --chown=node:node /app/examples ./examples
COPY --from=build --chown=node:node /app/app-config*.yaml ./

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7007/api/health || exit 1

# Expose port
EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]