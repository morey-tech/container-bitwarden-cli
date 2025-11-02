# Bitwarden CLI Container

A minimal container image for running the Bitwarden CLI in server mode (`bw serve`), providing an HTTP API for accessing your Bitwarden vault. Built on Red Hat UBI Micro for a reduced attack surface.

Typically used with the [External Secrets Operator `webhook` provider](https://external-secrets.io/latest/examples/bitwarden/) for Kubernetes secret management.

## Prerequisites

- A Bitwarden account (or self-hosted Bitwarden/Vaultwarden instance)
- Bitwarden API credentials (Client ID and Client Secret)
  - Generate at: https://vault.bitwarden.com/#/settings/security/security-keys (or your self-hosted instance)
- Master password for your Bitwarden vault

## Environment Variables

The container requires the following environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `BW_HOST` | Bitwarden server URL | `https://vault.bitwarden.com` or your self-hosted URL |
| `BW_CLIENTID` | API Client ID (from Bitwarden security settings) | `user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `BW_CLIENTSECRET` | API Client Secret (from Bitwarden security settings) | `xxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `BW_PASSWORD` | Master password for unlocking the vault | `your-master-password` |

**Note:** These environment variables should **never** be hardcoded or committed to version control. Always use a secrets management solution (Kubernetes Secrets, Docker Secrets, External Secrets Operator, etc.).

## Quick Start

### Podman

```bash
podman run -d \
  --name bitwarden-cli \
  -p 8087:8087 \
  -e BW_HOST="https://vault.bitwarden.com" \
  -e BW_CLIENTID="user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  -e BW_CLIENTSECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -e BW_PASSWORD="your-master-password" \
  ghcr.io/morey-tech/bitwarden-cli:latest
```

### Docker Compose

```yaml
version: '3.8'
services:
  bitwarden-cli:
    image: ghcr.io/morey-tech/bitwarden-cli:latest
    ports:
      - "8087:8087"
    environment:
      BW_HOST: https://vault.bitwarden.com
    env_file:
      - .env.bitwarden  # Contains BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD
    restart: unless-stopped
```

## Local Testing with Podman

### Build the Image

```bash
podman build -t bitwarden-cli:testing .
```

### Run and Test

```bash
# Run the container with your credentials
podman run --rm \
  -p 8087:8087 \
  -e BW_HOST="https://vault.bitwarden.com" \
  -e BW_CLIENTID="your-client-id" \
  -e BW_CLIENTSECRET="your-client-secret" \
  -e BW_PASSWORD="your-password" \
  bitwarden-cli:testing
```

### Verify the API is Working

In another terminal:

```bash
# Health check
curl http://localhost:8087/health

# List items (requires valid session)
curl http://localhost:8087/list/items
```

## Deployment Examples

### Kubernetes with External Secrets Operator

This container is designed to work seamlessly with the External Secrets Operator. See the [morey-tech/homelab example deployment](https://github.com/morey-tech/homelab/tree/main/kubernetes/rubrik/system/external-secrets) for a complete reference implementation.

**Example Deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bitwarden-cli
  namespace: external-secrets-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bitwarden-cli
  template:
    metadata:
      labels:
        app: bitwarden-cli
    spec:
      containers:
      - name: bitwarden-cli
        image: ghcr.io/morey-tech/bitwarden-cli:latest
        ports:
        - containerPort: 8087
          name: http
        env:
        - name: BW_HOST
          value: "https://vault.bitwarden.com"
        - name: BW_CLIENTID
          valueFrom:
            secretKeyRef:
              name: bitwarden-cli
              key: BW_CLIENTID
        - name: BW_CLIENTSECRET
          valueFrom:
            secretKeyRef:
              name: bitwarden-cli
              key: BW_CLIENTSECRET
        - name: BW_PASSWORD
          valueFrom:
            secretKeyRef:
              name: bitwarden-cli
              key: BW_PASSWORD
        livenessProbe:
          httpGet:
            path: /health
            port: 8087
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8087
          initialDelaySeconds: 10
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: bitwarden-cli
  namespace: external-secrets-system
spec:
  selector:
    app: bitwarden-cli
  ports:
  - port: 8087
    targetPort: 8087
    name: http
```

**Example SecretStore:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: bitwarden
  namespace: default
spec:
  provider:
    webhook:
      url: "http://bitwarden-cli.external-secrets-system.svc.cluster.local:8087/list/object/items/{{ .remoteRef.key }}"
      result:
        jsonPath: "$.data.password"
```

For more details, see the [External Secrets Bitwarden documentation](https://external-secrets.io/latest/examples/bitwarden/).

## Automated Updates

This repository includes automated version management:

- **Weekly Check**: Every Monday at 9 AM UTC, a GitHub Actions workflow checks for new Bitwarden CLI releases
- **Automatic PR**: If a new version is found, a PR is automatically created and merged
- **Image Build**: After merge, a new container image is built and pushed to the registry
- **Tagging**: Images are tagged with both the specific version (e.g., `2025.10.0`) and `latest`

You can view the automation workflow in [`.github/workflows/update-bitwarden-version.yml`](.github/workflows/update-bitwarden-version.yml).

## Container Registry & Tags

**Registry:** `ghcr.io/morey-tech/bitwarden-cli`

**Available Tags:**
- `latest` - Latest Bitwarden CLI version (updated automatically)
- `X.Y.Z` - Specific Bitwarden CLI version (e.g., `2025.10.0`)
- `<branch-name>` - Built from specific branches (via manual workflow)

**Pull the image:**

```bash
# Latest version
podman pull ghcr.io/morey-tech/bitwarden-cli:latest

# Specific version
podman pull ghcr.io/morey-tech/bitwarden-cli:2025.10.0
```

## API Reference

The container runs `bw serve` which provides an HTTP API on **port 8087**.

### Available Endpoints

The Bitwarden CLI server provides these endpoints:

- `GET /health` - Health check endpoint
- `GET /list/items` - List all vault items
- `GET /list/object/items/<id>` - Get a specific item by ID
- `GET /list/folders` - List all folders
- `GET /sync` - Sync the vault with the server

For complete API documentation, see the [Bitwarden CLI documentation](https://bitwarden.com/help/cli/#serve).

### Example API Calls

```bash
# Health check
curl http://localhost:8087/health

# List all items
curl http://localhost:8087/list/items

# Get specific item
curl http://localhost:8087/list/object/items/your-item-id
```

## Security Considerations

- **Never hardcode credentials**: Use environment variables with a secrets management solution
- **Avoid shell history**: Don't pass sensitive environment variables directly in shell commands; use files or orchestration tools
- **Network isolation**: In production, restrict access to port 8087 to only authorized services
- **Use specific versions**: Pin to specific version tags rather than `latest` for production deployments
- **Rotate credentials**: Regularly rotate your API credentials and master password
- **Minimal image**: This container uses Red Hat UBI Micro, a minimal "distroless" base image with a reduced attack surface

## Manual Build and Push (GitHub Actions)

This repository includes a manual workflow for building and pushing images:

1. Go to **Actions** → **Build and Push Container Image**
2. Click **Run workflow**
3. Select your branch
4. Optionally specify a custom tag
5. Optionally check "push_latest" to update the latest tag

## Links & Resources

- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [Bitwarden CLI GitHub Repository](https://github.com/bitwarden/clients)
- [External Secrets Operator](https://external-secrets.io/)
- [External Secrets Bitwarden Provider](https://external-secrets.io/latest/examples/bitwarden/)
- [Red Hat Universal Base Image (UBI)](https://developers.redhat.com/products/rhel/ubi)
- [Example Deployment (morey-tech/homelab)](https://github.com/morey-tech/homelab/tree/main/kubernetes/rubrik/system/external-secrets)

## License

This project uses the Bitwarden CLI, which is licensed under the GPL-3.0 License. See the [Bitwarden clients repository](https://github.com/bitwarden/clients) for details.
