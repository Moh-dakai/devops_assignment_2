#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Docker HEALTHCHECK script for the diagnostic CLI container
# =============================================================================
# Exits 0 if healthy, 1 if unhealthy.
# =============================================================================

SCRIPT_PATH="./app/diagnostic.sh"

# Check 1: script must exist
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "UNHEALTHY: $SCRIPT_PATH does not exist." >&2
    exit 1
fi

# Check 2: script must be executable
if [ ! -x "$SCRIPT_PATH" ]; then
    echo "UNHEALTHY: $SCRIPT_PATH is not executable." >&2
    exit 1
fi

# Check 3: running 'help' must exit 0
if ! "$SCRIPT_PATH" help >/dev/null 2>&1; then
    echo "UNHEALTHY: '$SCRIPT_PATH help' did not exit 0." >&2
    exit 1
fi

echo "HEALTHY: diagnostic.sh is present, executable, and responds to 'help'."
exit 0
