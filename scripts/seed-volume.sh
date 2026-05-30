#!/bin/bash
# Seed /opt/hermes volume from /opt/hermes-src on first start or version change.
# Sourced by entrypoint.sh.
set -e

SRC_DIR="/opt/hermes-src"
DST_DIR="${INSTALL_DIR:-/opt/hermes}"
REF_FILE="pyproject.toml"

if [ ! -d "$SRC_DIR" ]; then
    echo "[seed] No source directory found, skipping."
    return 0 2>/dev/null || exit 0
fi

HERMES_UID=$(id -u hermes)
HERMES_GID=$(id -g hermes)

# Case 1: Volume is empty — initial seed
if [ -z "$(ls -A "$DST_DIR" 2>/dev/null)" ]; then
    echo "[seed] /opt/hermes is empty, seeding from /opt/hermes-src..."
    cp -a "$SRC_DIR"/. "$DST_DIR"/
    chown -R "$HERMES_UID:$HERMES_GID" "$DST_DIR"
    echo "[seed] Initial seed complete."
    return 0 2>/dev/null || exit 0
fi

# Case 2: Compare versions via reference file hash
if [ -f "$SRC_DIR/$REF_FILE" ]; then
    SRC_HASH=$(sha256sum "$SRC_DIR/$REF_FILE" | awk '{print $1}')
    DST_HASH=$(sha256sum "$DST_DIR/$REF_FILE" 2>/dev/null | awk '{print $1}' || echo "")

    if [ "$SRC_HASH" != "$DST_HASH" ]; then
        echo "[seed] Version mismatch detected, updating volume..."
        # Preserve .venv to avoid expensive rebuild
        find "$DST_DIR" -mindepth 1 \
            ! -path "$DST_DIR/.venv" \
            ! -path "$DST_DIR/.venv/*" \
            -delete 2>/dev/null || true
        cp -a "$SRC_DIR"/. "$DST_DIR"/
        chown -R "$HERMES_UID:$HERMES_GID" "$DST_DIR"
        echo "[seed] Volume updated."
    else
        echo "[seed] /opt/hermes is already up to date."
    fi
fi