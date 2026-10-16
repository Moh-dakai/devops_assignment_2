#!/usr/bin/env bash
# =============================================================================
# diagnostic.sh — Dockerized Diagnostic CLI
# =============================================================================
# Usage:
#   diagnostic system
#   diagnostic network <host>
#   diagnostic disk
#   diagnostic help
#
# Exit codes:
#   0 — success
#   1 — runtime failure
#   2 — invalid command / missing required argument
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helper: print a section header
# ---------------------------------------------------------------------------
section() {
    echo ""
    echo "=============================="
    echo "  $1"
    echo "=============================="
}

# ---------------------------------------------------------------------------
# cmd_help — print usage information
# ---------------------------------------------------------------------------
cmd_help() {
    cat <<'EOF'
Diagnostic CLI — system diagnostics inside Docker
--------------------------------------------------
Usage:
  diagnostic <command> [options]

Commands:
  system              Show hostname, OS, kernel, uptime, CPU, and memory info
  network <host>      Resolve <host>, ping it, and show network interfaces
  disk                Show disk usage for all filesystems
  help                Print this help message

Exit codes:
  0   Success
  1   Runtime failure
  2   Invalid command or missing required argument

Examples:
  diagnostic system
  diagnostic network google.com
  diagnostic disk
  diagnostic help
EOF
}

# ---------------------------------------------------------------------------
# cmd_system — hostname, OS, kernel, uptime, CPU, memory
# ---------------------------------------------------------------------------
cmd_system() {
    section "hostname"
    hostname

    section "OS / Distribution"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release
    elif [ -f /etc/issue ]; then
        cat /etc/issue
    else
        echo "(unknown OS)"
    fi

    section "kernel"
    uname -r

    section "Uptime"
    uptime

    section "CPU Info"
    if [ -f /proc/cpuinfo ]; then
        grep -E "^(processor|model name|cpu MHz|cache size)" /proc/cpuinfo \
            | head -20 || echo "(unable to read /proc/cpuinfo)"
    else
        echo "(no /proc/cpuinfo available)"
    fi

    section "Memory Info"
    if [ -f /proc/meminfo ]; then
        grep -E "^(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree)" /proc/meminfo
    else
        echo "(no /proc/meminfo available)"
    fi
}

# ---------------------------------------------------------------------------
# cmd_network <host> — resolve, ping, show interfaces
# ---------------------------------------------------------------------------
cmd_network() {
    local host="$1"

    section "DNS Resolution for: $host"
    if command -v nslookup >/dev/null 2>&1; then
        nslookup "$host" || echo "(nslookup failed — host may be unreachable)"
    elif command -v host >/dev/null 2>&1; then
        host "$host" || echo "(host command failed)"
    else
        echo "(no DNS resolution tool available)"
    fi

    section "Ping: $host (4 packets)"
    if command -v ping >/dev/null 2>&1; then
        ping -c 4 "$host" 2>&1 || echo "(ping failed — host may be unreachable or ICMP blocked)"
    else
        echo "(ping not available)"
    fi

    section "Network Interfaces"
    if command -v ip >/dev/null 2>&1; then
        ip addr show
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig -a
    else
        echo "(no network interface tool available)"
    fi
}

# ---------------------------------------------------------------------------
# cmd_disk — disk usage for all filesystems
# ---------------------------------------------------------------------------
cmd_disk() {
    section "Disk Usage"
    df -h
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
main() {
    local command="${1:-help}"

    case "$command" in
        help | --help | -h)
            cmd_help
            exit 0
            ;;
        system)
            cmd_system
            exit 0
            ;;
        network)
            if [ -z "${2:-}" ]; then
                echo "Error: 'network' command requires a <host> argument." >&2
                echo "Usage: diagnostic network <host>" >&2
                exit 2
            fi
            cmd_network "$2"
            exit 0
            ;;
        disk)
            cmd_disk
            exit 0
            ;;
        *)
            echo "Error: Unknown command '${command}'." >&2
            echo "Run 'diagnostic help' for usage." >&2
            exit 2
            ;;
    esac
}

main "$@"
