# Global ARG for use in FROM instructions
ARG OPENCLAW_VERSION=latest

# Build Go proxy
FROM golang:1.22-bookworm AS proxy-builder

WORKDIR /proxy
COPY proxy/ .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /proxy-bin .

# Extend pre-built OpenClaw with our auth proxy
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

# Base image ends with USER node; switch to root for setup
USER root

# Add packages for openclaw agent operations
RUN apt-get update && apt-get install -y --no-install-recommends \
  ripgrep \
  vdirsyncer \
  khal \
  && rm -rf /var/lib/apt/lists/*

# Install bun runtime
RUN npm install -g bun

# Install mcporter CLI for MCP server management
RUN npm install -g mcporter

# Add proxy
COPY --from=proxy-builder /proxy-bin /usr/local/bin/proxy

# Create CLI wrapper
RUN printf '#!/bin/sh\nexec node /app/dist/index.js "$@"\n' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

ENV PORT=10000
EXPOSE 10000

# Run as non-root for security
USER node

CMD ["/usr/local/bin/proxy"]