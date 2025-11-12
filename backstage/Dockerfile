# Multi-stage Dockerfile for complete Backstage build (Multi-Platform Support)
FROM --platform=$BUILDPLATFORM node:22-bookworm-slim AS packages

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Print build info for debugging
RUN echo "Building on $BUILDPLATFORM, targeting $TARGETPLATFORM"

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

# Configure for cross-platform builds
ENV npm_config_target_arch=$TARGETARCH
ENV npm_config_target_platform=$TARGETOS
ENV npm_config_cache=/tmp/.npm
ENV CYPRESS_INSTALL_BINARY=0
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Skip problematic native modules that don't cross-compile well
ENV npm_config_optional=false

# Install dependencies with platform-specific optimizations
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    --mount=type=cache,target=/tmp/.npm,sharing=locked,uid=1000,gid=1000 \
    if [ "$TARGETARCH" = "arm64" ]; then \
      echo "ARM64 build - using extended timeout and fallback strategies"; \
      yarn install --immutable --network-timeout 900000 --ignore-engines || \
      yarn install --immutable --network-timeout 900000 --ignore-engines --ignore-scripts; \
    else \
      echo "AMD64 build - standard installation"; \
      yarn install --immutable --network-timeout 300000; \
    fi

FROM node:22-bookworm-slim AS build

ARG TARGETPLATFORM
ARG BUILDPLATFORM  
ARG TARGETOS
ARG TARGETARCH

# Set Python interpreter for `node-gyp` to use
ENV PYTHON=/usr/bin/python3

# Install build dependencies with architecture-specific packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    if [ "$TARGETARCH" = "arm64" ]; then \
      echo "Installing ARM64 build dependencies"; \
      apt-get install -y --no-install-recommends \
      python3 \
      g++ \
      build-essential \
      make \
      git \
      ca-certificates \
      libc6-dev \
      pkg-config; \
    else \
      echo "Installing AMD64 build dependencies"; \
      apt-get install -y --no-install-recommends \
      python3 \
      g++ \
      build-essential \
      make \
      git \
      ca-certificates; \
    fi && \
    rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /app

# Copy packages and dependencies from packages stage
COPY --from=packages --chown=node:node /app /app

# Copy application source
COPY --chown=node:node backstage/app-config*.yaml ./
COPY --chown=node:node backstage/catalog ./catalog
COPY --chown=node:node backstage/examples ./examples

# Build the application with platform-specific optimizations
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Use different build strategies based on target architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      echo "ARM64 build - using optimized settings"; \
      export NODE_OPTIONS="--max-old-space-size=6144"; \
      yarn build:backend --verbose || yarn build:backend --no-cache; \
    else \
      echo "AMD64 build - standard build"; \
      yarn build:backend; \
    fi

FROM node:22-bookworm-slim AS runtime

ARG TARGETARCH

# Install runtime dependencies with architecture considerations
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    g++ \
    build-essential \
    libsqlite3-dev \
    curl \
    ca-certificates \
    $([ "$TARGETARCH" = "arm64" ] && echo "libc6-dev") \
    && rm -rf /var/lib/apt/lists/*

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
    yarn workspaces focus --all --production && \
    yarn cache clean

# Copy any other files that the backend needs to run.
COPY --from=build --chown=node:node /app/examples ./examples
COPY --from=build --chown=node:node /app/app-config*.yaml ./

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7007/api/health || exit 1

# Expose port
EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]