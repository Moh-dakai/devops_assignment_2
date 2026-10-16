# =============================================================================
# Dockerfile — Diagnostic CLI Tool
# =============================================================================
# Builds a lightweight Alpine-based image with all tools needed for
# system, network, and disk diagnostics.
# =============================================================================

# Use Alpine as a lightweight base image
FROM alpine:3.19

# Install required packages:
#   bash          — required shell (scripts use #!/usr/bin/env bash)
#   curl          — HTTP requests / connectivity checks
#   bind-tools    — nslookup, dig (DNS resolution)
#   netcat-openbsd — nc for port checks
#   iputils       — ping
#   procps        — uptime, ps, and /proc utilities
RUN apk add --no-cache \
        bash \
        curl \
        bind-tools \
        netcat-openbsd \
        iputils \
        procps

# Set the working directory
WORKDIR /app

# Copy application scripts into the image
COPY app/ ./app/

# Ensure scripts are executable
RUN chmod +x app/diagnostic.sh app/health-check.sh

# Health check: runs every 30s, times out after 10s
HEALTHCHECK --interval=30s --timeout=10s \
    CMD ["./app/health-check.sh"]

# Default entrypoint is the diagnostic CLI
ENTRYPOINT ["./app/diagnostic.sh"]

# Default command shows help when no arguments are provided
CMD ["help"]
