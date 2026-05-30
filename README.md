## Usage

**Default (mautrix[encryption]):**
```bash
docker build -t takalele/hermes-agent:latest-profiles .
```

**Other packages:**
```bash
docker build -t takalele/hermes-agent:latest-profiles \
    --build-arg EXTRA_PIP_PACKAGES="mautrix[encryption] some-other-package another-lib" \
    --build-arg EXTRA_BUILD_DEPS="libffi-dev libolm-dev libxml2-dev" \
    --build-arg EXTRA_RUNTIME_DEPS="libolm3 libxml2" \
    .
```

**No extra packages (vanilla Hermes + supervisor):**
```bash
docker build -t my-hermes \
    --build-arg EXTRA_PIP_PACKAGES="" \
    --build-arg EXTRA_BUILD_DEPS="" \
    --build-arg EXTRA_RUNTIME_DEPS="" \
    .
```

## Build ARGs

| ARG | Stage | Purpose | Default |
|---|---|---|---|
| `EXTRA_PIP_PACKAGES` | builder + runtime | Python packages to build and install | `mautrix[encryption]` |
| `EXTRA_BUILD_DEPS` | builder | apt packages needed only for compiling wheels | `libffi-dev libolm-dev` |
| `EXTRA_RUNTIME_DEPS` | runtime | apt packages needed at runtime (shared libs etc.) | `libolm3` |

Everything else (startup scripts, supervisord, seeding, docker-compose) stays exactly the same.

## Docker Compose Options

### `extra_hosts` — Access host services from the container

If your LLM runs on the host machine (e.g. Ollama, LM Studio, vLLM), the container needs to reach it. Add `extra_hosts` to your `docker-compose.yml`:

```yaml
services:
  hermes-agent:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Then in your Hermes `.env`:
```bash
MODEL_API_BASE=http://host.docker.internal:11434/v1   # e.g. Ollama on host
```

Without this, the container cannot resolve `host.docker.internal`.

### `shm_size` — Shared memory for Playwright/Chromium

If Hermes uses Playwright for web research, Chromium needs more shared memory than Docker's default 64MB:

```yaml
services:
  hermes-agent:
    shm_size: "1gb"
```

### Full example with both options

```yaml
services:
  hermes-agent:
    image: takalele/hermes-agent:latest-profiles
    container_name: hermes_agent
    extra_hosts:
      - "host.docker.internal:host-gateway"
    shm_size: "1gb"
    restart: unless-stopped
    volumes:
      - ~/.hermes:/opt/data
      - hermes_src:/opt/hermes
    ports:
      - "8642:8642"
      - "9119:9119"
    environment:
      - HERMES_DASHBOARD=1
      - HERMES_UID=${UID:-1000}
      - HERMES_GID=${GID:-1000}
      - TZ=${TZ:-Europe/Berlin}
```

## API Server

Hermes has a built-in **OpenAI-compatible API endpoint**. This allows you to use Hermes as an API backend for other applications, scripts, or automations.

### Enable per profile

Add the following to each profile's `.env` file. **Each profile needs a unique port:**

```bash
# ~/.hermes/.env (main instance)
API_SERVER_ENABLED=true
API_SERVER_KEY=your-secret-key
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642

# ~/.hermes/profiles/researcher/.env
API_SERVER_ENABLED=true
API_SERVER_KEY=your-secret-key
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8643

# ~/.hermes/profiles/developer/.env
API_SERVER_ENABLED=true
API_SERVER_KEY=your-secret-key
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8644
```

### Expose ports in docker-compose.yml

```yaml
ports:
  - "8642:8642"   # main
  - "8643:8643"   # researcher
  - "8644:8644"   # developer
  - "8645:8645"   # writer
```

### Test the API

```bash
curl http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer your-secret-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "hermes", "messages": [{"role": "user", "content": "Hello"}]}'
```

> **Note:** The API server is optional. If you only use Hermes via Telegram, Discord, or the Dashboard, you don't need to enable it.

### important commands

```
docker exec -it hermes_agent supervisorctl status
docker exec -it hermes_agent supervisorctl restart hermes-main
docker exec -it hermes_agent supervisorctl restart all
docker exec -itu hermes hermes_agent bash
docker exec -itu hermes hermes_agent hermes model
docker exec -itu hermes hermes_agent hermes setup
docker exec -itu hermes hermes_agent hermes profile list
docker exec -itu hermes hermes_agent hermes -p <profilename> model
docker exec -itu hermes hermes_agent hermes kanban list
docker exec -itu hermes hermes_agent hermes kanban watch
```
