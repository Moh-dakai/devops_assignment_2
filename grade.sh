#!/usr/bin/env bash
# =============================================================================
# grade.sh — Grading script for Assignment 2: Dockerized Diagnostic CLI
# =============================================================================
# Checks file existence, syntax, permissions, Dockerfile content, Docker
# image smoke tests, test.sh execution, and git hygiene.
#
# NOTE: set -e is intentionally NOT used so all checks always run.
# =============================================================================

# ---------------------------------------------------------------------------
# Colour / scoring helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

pass_check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail_check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

header() {
    echo ""
    echo -e "${CYAN}## $1${NC}"
    echo "----------------------------------------------"
}

# ---------------------------------------------------------------------------
# 1. Required file existence
# ---------------------------------------------------------------------------
header "1. Required Files"

REQUIRED_FILES=(
    "README.md"
    "app/diagnostic.sh"
    "app/health-check.sh"
    "Dockerfile"
    "compose.yaml"
    ".dockerignore"
    "test.sh"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$f" ]; then
        pass_check "File exists: $f"
    else
        fail_check "File missing: $f"
    fi
done

# ---------------------------------------------------------------------------
# 2. Bash syntax check on all .sh files
# ---------------------------------------------------------------------------
header "2. Bash Syntax (bash -n)"

SH_FILES=(
    "app/diagnostic.sh"
    "app/health-check.sh"
    "test.sh"
    "grade.sh"
)

for f in "${SH_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        fail_check "Syntax check skipped (file missing): $f"
        continue
    fi
    if bash -n "$f" 2>/dev/null; then
        pass_check "Syntax OK: $f"
    else
        fail_check "Syntax errors in: $f"
    fi
done

# ---------------------------------------------------------------------------
# 3. Executable permissions
# ---------------------------------------------------------------------------
header "3. Executable Permissions"

EXEC_FILES=(
    "app/diagnostic.sh"
    "app/health-check.sh"
)

for f in "${EXEC_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        fail_check "Permission check skipped (file missing): $f"
        continue
    fi
    if [ -x "$f" ]; then
        pass_check "Executable: $f"
    else
        fail_check "Not executable: $f (run: chmod +x $f)"
    fi
done

# ---------------------------------------------------------------------------
# 4. Dockerfile content checks
# ---------------------------------------------------------------------------
header "4. Dockerfile Content"

if [ ! -f "Dockerfile" ]; then
    fail_check "Dockerfile missing — skipping content checks"
else
    DOCKERFILE_KEYWORDS=("FROM" "COPY" "RUN" "HEALTHCHECK")
    for kw in "${DOCKERFILE_KEYWORDS[@]}"; do
        if grep -q "^${kw}" Dockerfile; then
            pass_check "Dockerfile contains: ${kw}"
        else
            fail_check "Dockerfile missing: ${kw}"
        fi
    done

    # ENTRYPOINT OR CMD
    if grep -qE "^(ENTRYPOINT|CMD)" Dockerfile; then
        pass_check "Dockerfile contains: ENTRYPOINT or CMD"
    else
        fail_check "Dockerfile missing: ENTRYPOINT or CMD"
    fi
fi

# ---------------------------------------------------------------------------
# 5. .dockerignore content
# ---------------------------------------------------------------------------
header "5. .dockerignore Content"

if [ ! -f ".dockerignore" ]; then
    fail_check ".dockerignore missing"
else
    if grep -q "\.git" .dockerignore; then
        pass_check ".dockerignore contains '.git' entry"
    else
        fail_check ".dockerignore does not contain '.git' entry"
    fi
fi

# ---------------------------------------------------------------------------
# 6. compose.yaml content
# ---------------------------------------------------------------------------
header "6. compose.yaml Content"

if [ ! -f "compose.yaml" ]; then
    fail_check "compose.yaml missing"
else
    if grep -q "diagnostic" compose.yaml; then
        pass_check "compose.yaml contains 'diagnostic' service"
    else
        fail_check "compose.yaml missing 'diagnostic' service"
    fi
fi

# ---------------------------------------------------------------------------
# 7. Docker smoke tests (if Docker is available)
# ---------------------------------------------------------------------------
header "7. Docker Smoke Tests"

GRADE_IMAGE="diagnostic-tool-grade"

if ! command -v docker >/dev/null 2>&1; then
    info "Docker not available — skipping Docker tests"
else
    info "Building Docker image '${GRADE_IMAGE}' for smoke tests ..."
    if docker build -t "${GRADE_IMAGE}" . >/dev/null 2>&1; then
        pass_check "Docker build succeeded"

        # Smoke test: help
        docker run --rm "${GRADE_IMAGE}" help >/dev/null 2>&1
        EC=$?
        if [ "$EC" -eq 0 ]; then
            pass_check "Smoke test: 'help' exits 0"
        else
            fail_check "Smoke test: 'help' exited $EC (expected 0)"
        fi

        # Smoke test: system
        docker run --rm "${GRADE_IMAGE}" system >/dev/null 2>&1
        EC=$?
        if [ "$EC" -eq 0 ]; then
            pass_check "Smoke test: 'system' exits 0"
        else
            fail_check "Smoke test: 'system' exited $EC (expected 0)"
        fi

        # Smoke test: disk
        docker run --rm "${GRADE_IMAGE}" disk >/dev/null 2>&1
        EC=$?
        if [ "$EC" -eq 0 ]; then
            pass_check "Smoke test: 'disk' exits 0"
        else
            fail_check "Smoke test: 'disk' exited $EC (expected 0)"
        fi

        # Smoke test: invalid command returns non-zero
        docker run --rm "${GRADE_IMAGE}" invalid-command >/dev/null 2>&1
        EC=$?
        if [ "$EC" -ne 0 ]; then
            pass_check "Smoke test: 'invalid-command' exits non-zero (got $EC)"
        else
            fail_check "Smoke test: 'invalid-command' exited 0 (expected non-zero)"
        fi

        # Smoke test: network with no host returns 2
        docker run --rm "${GRADE_IMAGE}" network >/dev/null 2>&1
        EC=$?
        if [ "$EC" -eq 2 ]; then
            pass_check "Smoke test: 'network' (no host) exits 2"
        else
            fail_check "Smoke test: 'network' (no host) exited $EC (expected 2)"
        fi

        # Cleanup
        docker rmi "${GRADE_IMAGE}" >/dev/null 2>&1
        info "Removed grading image '${GRADE_IMAGE}'"
    else
        fail_check "Docker build failed — skipping smoke tests"
    fi
fi

# ---------------------------------------------------------------------------
# 8. Run test.sh (if executable)
# ---------------------------------------------------------------------------
header "8. test.sh Execution"

if [ ! -f "test.sh" ]; then
    fail_check "test.sh missing — skipping"
elif [ ! -x "test.sh" ]; then
    fail_check "test.sh is not executable (run: chmod +x test.sh)"
elif ! command -v docker >/dev/null 2>&1; then
    info "Docker not available — skipping test.sh execution"
else
    info "Running test.sh ..."
    if bash test.sh; then
        pass_check "test.sh completed successfully (all tests passed)"
    else
        fail_check "test.sh reported one or more test failures"
    fi
fi

# ---------------------------------------------------------------------------
# 9. Git checks
# ---------------------------------------------------------------------------
header "9. Git Hygiene"

if ! command -v git >/dev/null 2>&1; then
    info "git not available — skipping git checks"
else
    # Check commit count
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    if [ "$COMMIT_COUNT" -ge 5 ]; then
        pass_check "Git: at least 5 commits (found ${COMMIT_COUNT})"
    else
        fail_check "Git: fewer than 5 commits (found ${COMMIT_COUNT})"
    fi

    # Check non-main branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        pass_check "Git: working on feature branch '${CURRENT_BRANCH}' (not main/master)"
    else
        fail_check "Git: currently on '${CURRENT_BRANCH}' — expected a non-main feature branch"
    fi
fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo -e "${CYAN}  GRADING SUMMARY${NC}"
echo "=============================================="
echo "  Total checks : ${TOTAL_CHECKS}"
echo -e "  Passed       : ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "  Failed       : ${RED}${FAILED_CHECKS}${NC}"
echo ""

SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
echo "  Score: ${SCORE}%"

if [ "${FAILED_CHECKS}" -eq 0 ]; then
    echo -e "  ${GREEN}All checks passed — excellent work!${NC}"
else
    echo -e "  ${RED}${FAILED_CHECKS} check(s) failed — review the output above.${NC}"
fi
echo "=============================================="
