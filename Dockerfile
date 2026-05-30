# ---------- Stage 1: Wheel-Builder for additional Python packages ----------
FROM debian:13.4 AS builder

ARG EXTRA_PIP_PACKAGES="mautrix[encryption]"
ARG EXTRA_BUILD_DEPS="libffi-dev libolm-dev"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip python3-dev \
        build-essential \
        ${EXTRA_BUILD_DEPS} \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /venv
ENV PATH="/venv/bin:${PATH}"

RUN pip install --no-cache-dir wheel && \
    if [ -n "$EXTRA_PIP_PACKAGES" ]; then \
        pip wheel --no-cache-dir $EXTRA_PIP_PACKAGES -w /wheels; \
    fi

# ---------- Stage 2: Runtime based on Hermes ----------
FROM nousresearch/hermes-agent:latest

USER root

ARG EXTRA_RUNTIME_DEPS="libolm3"
ARG EXTRA_PIP_PACKAGES="mautrix[encryption]"

RUN if [ -n "$EXTRA_RUNTIME_DEPS" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            supervisor vim nano net-tools iproute2 \
            ${EXTRA_RUNTIME_DEPS} \
        && rm -rf /var/lib/apt/lists/*; \
    else \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            supervisor vim nano net-tools iproute2 \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Install built wheels (only if packages were requested)
COPY --from=builder /wheels /tmp/wheels
RUN if [ -d /tmp/wheels ] && ls /tmp/wheels/*.whl 1>/dev/null 2>&1; then \
        uv pip install --no-cache-dir /tmp/wheels/*.whl; \
    fi && \
    rm -rf /tmp/wheels

# Preserve original source for volume seeding
RUN cp -a /opt/hermes /opt/hermes-src

# scripts
COPY scripts/ /usr/local/bin/hermes/
COPY configs/supervisord.conf     /etc/supervisor/supervisord.conf

RUN chmod +x /usr/local/bin/hermes/*.sh

# Auto-activate venv on bash login
RUN echo 'source /opt/hermes/.venv/bin/activate' >> /opt/data/.bashrc
RUN echo 'source /opt/hermes/.venv/bin/activate' >> /root/.bashrc

#USER hermes
#WORKDIR /opt/data
#ENV HOME=/opt/data
ENV HERMES_HOME=/opt/data
ENV HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist
ENV PATH="/opt/data/.local/bin:${PATH}"
VOLUME ["/opt/hermes"]

ENTRYPOINT ["/usr/local/bin/hermes/entrypoint.sh"]