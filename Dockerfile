# Builder stage - download and extract Bitwarden CLI
FROM registry.access.redhat.com/ubi10/ubi:latest AS builder

ENV BW_CLI_VERSION=2025.12.0

RUN dnf install -y wget unzip libstdc++ && \
    wget https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip && \
    unzip bw-linux-${BW_CLI_VERSION}.zip && \
    chmod +x bw

# Runtime stage - minimal distroless image
FROM registry.access.redhat.com/ubi10/ubi-micro:latest

# Copy Bitwarden CLI binary
COPY --from=builder /bw /usr/local/bin/bw

# Copy required shared libraries
COPY --from=builder /lib64/libstdc++.so.6 /lib64/libstdc++.so.6
COPY --from=builder /lib64/libgcc_s.so.1 /lib64/libgcc_s.so.1

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Create non-root user and set up directories with OpenShift compatibility
# Use GID 0 (root group) and group-writable permissions for arbitrary UIDs
RUN chmod +x /entrypoint.sh && \
    useradd -u 1000 -g 0 -m -d /home/bwcli bwcli && \
    mkdir -p /home/bwcli/.config/Bitwarden\ CLI && \
    chown -R 1000:0 /home/bwcli && \
    chmod -R g=u /home/bwcli && \
    chmod 775 /home/bwcli /home/bwcli/.config /home/bwcli/.config/Bitwarden\ CLI

# Set environment variables
ENV HOME=/home/bwcli

# Switch to non-root user (OpenShift will override UID but keep GID 0)
USER 1000

CMD ["/entrypoint.sh"]
