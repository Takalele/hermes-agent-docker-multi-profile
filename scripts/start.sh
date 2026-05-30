#!/bin/bash
# Called by supervisord for each instance: set up environment, start hermes.
set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/hermes}"
API_SERVER_PORT="${API_SERVER_PORT:-8642}"

# Handle optional -p PROFILE flag (profile instance)
HERMES_PROFILE=""
if [ "$1" = "-p" ]; then
    HERMES_PROFILE="$2"
    export HERMES_HOME="/opt/data/profiles/$2"
    shift 2
fi

export HOME="${HERMES_HOME:-/opt/data}"

export HERMES_HOME="${HERMES_HOME:-/opt/data}"

source "${INSTALL_DIR}/.venv/bin/activate"

# Create essential directory structure
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills,skins,plans,workspace,home}

# Seed missing config files
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

# Sync bundled skills (manifest-based, preserves user edits)
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

if [ -n "$HERMES_PROFILE" ]; then
    exec hermes -p "$HERMES_PROFILE" "$@"
else
    exec hermes "$@"
fi