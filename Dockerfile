# Home Assistant Add-on Base Image Pattern
# Uses ARG BUILD_FROM to support multi-architecture builds via build.yaml
# Default to Alpine if no BUILD_FROM is provided (for testing)
# hadolint ignore=DL3006
ARG BUILD_FROM=alpine:3.21
FROM ${BUILD_FROM}

# Install bash first if not already available (needed for SHELL directive)
# hadolint ignore=DL3018
RUN if ! command -v bash >/dev/null 2>&1; then \
        apk add --no-cache bash=5.2.37-r0 || apk add --no-cache bash; \
    fi

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set environment variables
ENV LANG=C.UTF-8
ENV PERIPHERY_CONFIG_DIR=/data/config
ENV PERIPHERY_DATA_DIR=/data
ENV PERIPHERY_SSL_DIR=/data/ssl

# Install required packages with version fallback strategy
# Package versions updated for Alpine 3.21 - update periodically
# Try pinned versions first, fall back to latest if not available
# This ensures compatibility across different base images and Alpine versions
# hadolint ignore=DL3018
RUN set -e; \
    echo "Installing packages with version fallback..."; \
    apk add --no-cache \
        curl=8.12.1-r0 \
        docker-cli=27.4.1-r0 \
        openssl=3.3.2-r4 \
        procps-ng=4.0.4-r0 \
    || { \
        echo "Pinned versions failed, trying latest versions..."; \
        apk add --no-cache \
            curl \
            docker-cli \
            openssl \
            procps-ng; \
    } \
    && rm -rf /var/cache/apk/*

# Create necessary directories
RUN mkdir -p ${PERIPHERY_CONFIG_DIR} ${PERIPHERY_SSL_DIR}

# Download and install Komodo Periphery binary
ARG KOMODO_VERSION=latest
RUN ARCH=$(uname -m) \
    && case $ARCH in \
        x86_64) ARCH_NAME="x86_64" ;; \
        aarch64) ARCH_NAME="aarch64" ;; \
        armv7l) ARCH_NAME="armv7" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac \
    && if [ "$KOMODO_VERSION" = "latest" ]; then \
        DOWNLOAD_URL="https://github.com/moghtech/komodo/releases/latest/download/periphery-$ARCH_NAME"; \
    else \
        DOWNLOAD_URL="https://github.com/moghtech/komodo/releases/download/$KOMODO_VERSION/periphery-$ARCH_NAME"; \
    fi \
    && curl -fsSL "$DOWNLOAD_URL" -o /usr/local/bin/periphery \
    && chmod +x /usr/local/bin/periphery

# Create non-root user for security
RUN addgroup -g 1000 komodo \
    && adduser -D -s /bin/bash -G komodo -u 1000 komodo \
    && (getent group docker >/dev/null || addgroup docker) \
    && addgroup komodo docker

# Set proper permissions
RUN chown -R komodo:komodo ${PERIPHERY_DATA_DIR}

# Copy run script
COPY rootfs /

# Make run script executable
RUN chmod a+x /etc/services.d/komodo-periphery/run

# Labels
LABEL \
    io.hass.name="Komodo Periphery" \
    io.hass.description="Komodo Periphery Agent for Home Assistant OS monitoring" \
    io.hass.arch="armhf|aarch64|amd64" \
    io.hass.type="addon" \
    io.hass.version="1.0.0" \
    maintainer="Home Assistant Community" \
    org.opencontainers.image.title="Komodo Periphery Add-on" \
    org.opencontainers.image.description="Run Komodo Periphery agent to monitor HAOS system metrics" \
    org.opencontainers.image.source="https://github.com/moghtech/komodo" \
    org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f -k https://localhost:${PERIPHERY_PORT:-8120}/health || exit 1

# Expose default Komodo Periphery port
EXPOSE 8120

# Switch to non-root user
USER komodo

# Start service using s6 overlay
CMD ["/init"]
