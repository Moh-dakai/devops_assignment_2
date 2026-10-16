# Assignment 2: Dockerized Diagnostic CLI

A containerized command-line diagnostic tool built with Bash and Docker (Alpine Linux). It provides quick system, network, and disk diagnostics through a clean CLI interface, packaged as a self-contained Docker image.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Usage](#usage)
  - [Direct (inside container)](#direct-inside-container)
  - [Docker run](#docker-run)
  - [Docker Compose](#docker-compose)
- [Commands Reference](#commands-reference)
- [Exit Codes](#exit-codes)
- [Health Check](#health-check)
- [Testing](#testing)
- [Grading](#grading)
- [Assumptions & Design Notes](#assumptions--design-notes)

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Docker | 20.10+ | Required to build and run the image |
| Docker Compose | v2 (plugin) | For `compose.yaml` usage |
| Bash | 4.0+ | Required to run `test.sh` and `grade.sh` on the host |
| Git | Any | Required for git hygiene checks in `grade.sh` |

> **Windows users:** Run `test.sh` and `grade.sh` inside WSL2 or Git Bash.

---

## Project Structure

```
assignment-2/
├── README.md               # This file
├── Dockerfile              # Alpine-based image definition
├── compose.yaml            # Docker Compose service definition
├── .dockerignore           # Build context exclusions
├── test.sh                 # Integration test suite
├── grade.sh                # Automated grading script
└── app/
    ├── diagnostic.sh       # Main CLI entry point
    └── health-check.sh     # Docker HEALTHCHECK script
```

---

## Setup

### 1. Clone / navigate to the project

```bash
cd assignment-2
```

### 2. Build the Docker image

```bash
docker build -t diagnostic-tool:latest .
```

---

## Usage

### Direct (inside container)

```bash
# Start an interactive shell in the container
docker run --rm -it --entrypoint bash diagnostic-tool:latest

# Then run commands inside
./app/diagnostic.sh system
./app/diagnostic.sh network google.com
./app/diagnostic.sh disk
./app/diagnostic.sh help
```

### Docker run

```bash
# Show help
docker run --rm diagnostic-tool:latest help

# System diagnostics
docker run --rm diagnostic-tool:latest system

# Network diagnostics
docker run --rm diagnostic-tool:latest network google.com

# Disk usage
docker run --rm diagnostic-tool:latest disk
```

### Docker Compose

```bash
# System diagnostics
docker compose run --rm diagnostic system

# Network diagnostics
docker compose run --rm diagnostic network google.com

# Disk usage
docker compose run --rm diagnostic disk

# Help
docker compose run --rm diagnostic help
```

---

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `system` | Hostname, OS info, kernel version, uptime, CPU, memory | `diagnostic system` |
| `network <host>` | DNS resolution, ping (4 packets), network interfaces | `diagnostic network google.com` |
| `disk` | Disk usage for all filesystems (`df -h`) | `diagnostic disk` |
| `help` | Print usage / help text | `diagnostic help` |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Runtime failure |
| `2` | Invalid command or missing required argument |

---

## Health Check

The image includes a Docker `HEALTHCHECK` that:

1. Verifies `app/diagnostic.sh` exists
2. Verifies `app/diagnostic.sh` is executable
3. Runs `./app/diagnostic.sh help` and checks for exit code 0

The health check runs every **30 seconds** with a **10-second timeout**.

Check container health status with:

```bash
docker inspect --format='{{.State.Health.Status}}' <container_id>
```

---

## Testing

The `test.sh` script builds a test image (`diagnostic-tool-test`) and runs six integration tests:

```bash
chmod +x test.sh
./test.sh
```

Tests performed:
1. `help` exits 0
2. `system` exits 0
3. `system` output contains `hostname`, `kernel`, or `CPU`
4. `disk` exits 0
5. `invalid-command` exits 2
6. `network` (no host) exits 2
7. `network localhost` exits 0

The test image is automatically removed after the suite completes.

---

## Grading

```bash
chmod +x grade.sh
./grade.sh
```

The grading script checks:
- ✅ Required files exist
- ✅ Bash syntax is valid (`bash -n`)
- ✅ Scripts are executable
- ✅ Dockerfile contains required instructions
- ✅ `.dockerignore` includes `.git`
- ✅ `compose.yaml` includes the `diagnostic` service
- ✅ Docker smoke tests (if Docker available)
- ✅ `test.sh` runs cleanly
- ✅ Git: ≥ 5 commits, on a feature branch

---

## Assumptions & Design Notes

- **Alpine Linux 3.19** is used as the base for a minimal attack surface and small image size (~20 MB).
- **`set -euo pipefail`** is used in `diagnostic.sh` for robust error handling; `grade.sh` intentionally omits `set -e` so all checks always run regardless of failures.
- **Network failures are non-fatal**: `ping` and `nslookup` failures inside `network` print warnings but still exit 0, since network restrictions inside Docker containers are expected in some environments.
- **`/proc` filesystem**: CPU and memory data are read from `/proc/cpuinfo` and `/proc/meminfo` respectively; the `procps` package ensures `uptime` is available.
- **`bind-tools`** provides `nslookup` and `dig` on Alpine; `iputils` provides `ping`.
- The `compose.yaml` uses the modern `services:` syntax compatible with Docker Compose v2.
