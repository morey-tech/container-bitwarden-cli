# Builder stage - download and extract Bitwarden CLI
FROM registry.access.redhat.com/ubi10/ubi:latest AS builder

ENV BW_CLI_VERSION=2025.10.0

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

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
