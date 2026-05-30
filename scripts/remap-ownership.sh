#!/bin/bash
# UID/GID remapping for host volume compatibility.
# Sourced by entrypoint.sh — does not exec, just sets up ownership.
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"
INSTALL_DIR="${INSTALL_DIR:-/opt/hermes}"

if [ "$(id -u)" = "0" ]; then
    REMAPPED=0

    if [ -n "$HERMES_UID" ] && [ "$HERMES_UID" != "$(id -u hermes)" ]; then
        echo "[remap] Changing hermes UID to $HERMES_UID"
        usermod -u "$HERMES_UID" hermes
        REMAPPED=1
    fi

    if [ -n "$HERMES_GID" ] && [ "$HERMES_GID" != "$(id -g hermes)" ]; then
        echo "[remap] Changing hermes GID to $HERMES_GID"
        groupmod -o -g "$HERMES_GID" hermes 2>/dev/null || true
        REMAPPED=1
    fi

    if [ "$REMAPPED" = "1" ]; then
        chown -R hermes:hermes "$HERMES_HOME" "$INSTALL_DIR" 2>/dev/null || \
            echo "[remap] Warning: chown failed (rootless container?) — continuing anyway"
    fi
fi