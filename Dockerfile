# Builder stage - download and extract Bitwarden CLI
FROM registry.access.redhat.com/ubi10/ubi:latest AS builder

ENV BW_CLI_VERSION=2025.12.0

RUN dnf install -y wget unzip libstdc++ && \
    wget https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip && \
    unzip bw-linux-${BW_CLI_VERSION}.zip && \
    chmod +x bw

# Create non-root user in builder stage (shadow-utils available here)
# ubi-micro no longer includes shadow-utils as of Dec 2025
RUN useradd -u 1000 -g 0 -m -d /home/bwcli bwcli && \
    mkdir -p /home/bwcli/.config/Bitwarden\ CLI && \
    chown -R 1000:0 /home/bwcli && \
    chmod -R g=u /home/bwcli && \
    chmod 775 /home/bwcli /home/bwcli/.config /home/bwcli/.config/Bitwarden\ CLI

# Runtime stage - minimal distroless image
FROM registry.access.redhat.com/ubi10/ubi-micro:latest

# Copy Bitwarden CLI binary
COPY --from=builder /bw /usr/local/bin/bw

# Copy required shared libraries
COPY --from=builder /lib64/libstdc++.so.6 /lib64/libstdc++.so.6
COPY --from=builder /lib64/libgcc_s.so.1 /lib64/libgcc_s.so.1

# Copy user/group database and home directory from builder
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder --chown=1000:0 /home/bwcli /home/bwcli

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Set environment variables
ENV HOME=/home/bwcli

# Switch to non-root user (OpenShift will override UID but keep GID 0)
USER 1000

CMD ["/entrypoint.sh"]
