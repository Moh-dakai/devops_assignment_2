#!/usr/bin/env bash
# =============================================================================
# test.sh — Integration test suite for the Diagnostic CLI Docker image
# =============================================================================
# Builds the Docker image, runs a set of container tests, cleans up,
# and prints a pass/fail summary.
#
# Usage:
#   chmod +x test.sh
#   ./test.sh
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
IMAGE_NAME="diagnostic-tool-test"
PASS_COUNT=0
FAIL_COUNT=0

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# ---------------------------------------------------------------------------
# pass / fail helpers
# ---------------------------------------------------------------------------
pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# ---------------------------------------------------------------------------
# Build the Docker image
# ---------------------------------------------------------------------------
info "Building Docker image '${IMAGE_NAME}' ..."
if docker build -t "${IMAGE_NAME}" . >/dev/null 2>&1; then
    info "Image built successfully."
else
    echo -e "${RED}[ERROR]${NC} Docker build failed. Aborting tests." >&2
    exit 1
fi

echo ""
echo "Running tests ..."
echo "----------------------------------------------"

# ---------------------------------------------------------------------------
# Test 1: 'help' exits 0
# ---------------------------------------------------------------------------
docker run --rm "${IMAGE_NAME}" help >/dev/null 2>&1
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "Test 1: 'help' exits 0"
else
    fail "Test 1: 'help' exited ${EXIT_CODE} (expected 0)"
fi

# ---------------------------------------------------------------------------
# Test 2: 'system' exits 0 and output contains expected keywords
# ---------------------------------------------------------------------------
SYSTEM_OUTPUT=$(docker run --rm "${IMAGE_NAME}" system 2>&1)
SYSTEM_EXIT=$?
if [ "${SYSTEM_EXIT}" -eq 0 ]; then
    pass "Test 2a: 'system' exits 0"
else
    fail "Test 2a: 'system' exited ${SYSTEM_EXIT} (expected 0)"
fi

if echo "${SYSTEM_OUTPUT}" | grep -qiE "hostname|kernel|cpu"; then
    pass "Test 2b: 'system' output contains 'hostname', 'kernel', or 'CPU'"
else
    fail "Test 2b: 'system' output missing expected keywords (hostname/kernel/CPU)"
fi

# ---------------------------------------------------------------------------
# Test 3: 'disk' exits 0
# ---------------------------------------------------------------------------
docker run --rm "${IMAGE_NAME}" disk >/dev/null 2>&1
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "Test 3: 'disk' exits 0"
else
    fail "Test 3: 'disk' exited ${EXIT_CODE} (expected 0)"
fi

# ---------------------------------------------------------------------------
# Test 4: unknown command exits 2
# ---------------------------------------------------------------------------
docker run --rm "${IMAGE_NAME}" invalid-command >/dev/null 2>&1
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 2 ]; then
    pass "Test 4: 'invalid-command' exits 2"
else
    fail "Test 4: 'invalid-command' exited ${EXIT_CODE} (expected 2)"
fi

# ---------------------------------------------------------------------------
# Test 5: 'network' with no host exits 2
# ---------------------------------------------------------------------------
docker run --rm "${IMAGE_NAME}" network >/dev/null 2>&1
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 2 ]; then
    pass "Test 5: 'network' (no host) exits 2"
else
    fail "Test 5: 'network' (no host) exited ${EXIT_CODE} (expected 2)"
fi

# ---------------------------------------------------------------------------
# Test 6: 'network localhost' exits 0
# ---------------------------------------------------------------------------
docker run --rm "${IMAGE_NAME}" network localhost >/dev/null 2>&1
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "Test 6: 'network localhost' exits 0"
else
    fail "Test 6: 'network localhost' exited ${EXIT_CODE} (expected 0)"
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
echo ""
info "Cleaning up test image '${IMAGE_NAME}' ..."
docker rmi "${IMAGE_NAME}" >/dev/null 2>&1 && info "Image removed." || info "Could not remove image (may not exist)."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "  Results: ${PASS_COUNT} / ${TOTAL} passed"
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "  ${GREEN}All tests passed!${NC}"
    echo "=============================================="
    exit 0
else
    echo -e "  ${RED}${FAIL_COUNT} test(s) failed.${NC}"
    echo "=============================================="
    exit 1
fi
