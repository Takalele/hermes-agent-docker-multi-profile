#!/bin/bash
# Docker ENTRYPOINT: seed volume, remap ownership, generate supervisor configs, start supervisord.
set -e

HERMES_DATA="${HERMES_HOME:-/opt/data}"
INSTALL_DIR="${INSTALL_DIR:-/opt/hermes}"
SCRIPTS_DIR="/usr/local/bin/hermes"
SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"

# --- 1. Seed /opt/hermes volume from image source ---
source "$SCRIPTS_DIR/seed-volume.sh"

# --- 2. Remap UID/GID if requested ---
source "$SCRIPTS_DIR/remap-ownership.sh"

# --- 3. Ensure volume ownership after seeding ---
chown hermes:hermes "$INSTALL_DIR" 2>/dev/null || true

# --- 4. Create supervisor configuration directory ---
mkdir -p "$SUPERVISOR_CONF_DIR"

# --- 5. Generate supervisor config for main instance ---
cat > "$SUPERVISOR_CONF_DIR/hermes-main.conf" << EOF
[program:hermes-main]
command=$SCRIPTS_DIR/start.sh gateway run
directory=$HERMES_DATA
user=hermes
autostart=true
autorestart=true
startretries=5
startsecs=10
environment=HERMES_HOME="$HERMES_DATA",INSTALL_DIR="$INSTALL_DIR"
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
EOF
echo "[entrypoint] Main instance configured"

# --- 6. Generate supervisor config for each profile ---
if [ -d "$HERMES_DATA/profiles" ]; then
    for profile_dir in "$HERMES_DATA/profiles"/*/; do
        [ -d "$profile_dir" ] || continue
        NAME=$(basename "$profile_dir")

        # Only register profiles that have been configured
        if [ -f "$profile_dir/config.yaml" ] || [ -f "$profile_dir/.env" ]; then
            cat > "$SUPERVISOR_CONF_DIR/hermes-${NAME}.conf" << EOF
[program:hermes-${NAME}]
command=$SCRIPTS_DIR/start.sh -p $NAME gateway run
directory=${profile_dir%/}
user=hermes
autostart=true
autorestart=true
startretries=5
startsecs=10
environment=HERMES_HOME="${profile_dir%/}",INSTALL_DIR="$INSTALL_DIR"
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
EOF
            echo "[entrypoint] Profile '$NAME' configured"
        else
            echo "[entrypoint] Profile '$NAME' skipped (no config.yaml or .env found)."
        fi
    done
fi

# --- 7. Dashboard (if enabled, cleanup if disabled) ---
DASHBOARD_CONF="$SUPERVISOR_CONF_DIR/hermes-dashboard.conf"
case "${HERMES_DASHBOARD:-}" in
    1|true|TRUE|True|yes|YES|Yes)
        dash_host="${HERMES_DASHBOARD_HOST:-0.0.0.0}"
        dash_port="${HERMES_DASHBOARD_PORT:-9119}"
        dash_args="--host $dash_host --port $dash_port --no-open"
        # Binding to anything other than localhost requires --insecure
        if [ "$dash_host" != "127.0.0.1" ] && [ "$dash_host" != "localhost" ]; then
            dash_args="$dash_args --insecure"
        fi
        cat > "$DASHBOARD_CONF" << EOF
[program:hermes-dashboard]
command=$INSTALL_DIR/.venv/bin/hermes dashboard $dash_args
directory=$HERMES_DATA
user=hermes
autostart=true
autorestart=true
startretries=5
startsecs=5
environment=HERMES_HOME="$HERMES_DATA",INSTALL_DIR="$INSTALL_DIR"
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
EOF
        echo "[entrypoint] Dashboard enabled on ${dash_host}:${dash_port}"
        ;;
    *)
        # Remove stale dashboard config from previous runs
        rm -f "$DASHBOARD_CONF"
        ;;
esac

# --- 8. Start supervisord ---
echo "[entrypoint] Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf