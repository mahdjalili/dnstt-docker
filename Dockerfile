FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and Dante server
RUN apt-get update && \
    apt-get install -y \
    curl \
    dante-server \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Setup architecture and download dnstt-server
RUN ARCH=$(uname -m) && \
    case $ARCH in \
        x86_64) DNSTT_ARCH="amd64" ;; \
        aarch64|arm64) DNSTT_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -L -o /tmp/dnstt-server "https://dnstt.network/dnstt-server-linux-${DNSTT_ARCH}" && \
    chmod +x /tmp/dnstt-server && \
    mv /tmp/dnstt-server /usr/local/bin/

# Create config directory
RUN mkdir -p /etc/dnstt

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
# 5300: dnstt tunnel
# 1080: socks proxy (optional access)
# 53: standard DNS (mapped externally)
EXPOSE 5300/udp 1080/tcp 53/udp

ENTRYPOINT ["/entrypoint.sh"]