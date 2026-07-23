FROM node:24-slim

# Build arguments for non-sensitive configuration
ARG AWS_CODEARTIFACT_DOMAIN
ARG AWS_ACCOUNT_ID
ARG AWS_REGION
ARG CODEARTIFACT_REPO=pose-repo

WORKDIR /app

# Copy package files
COPY package*.json ./

# Use BuildKit secret mount for the CodeArtifact token.
# Configures npm against CodeArtifact and runs npm ci so an invalid/expired
# token fails the build (401) instead of silently falling back to public npm.
RUN --mount=type=secret,id=codeartifact_token,required=true \
    set -eu; \
    TOKEN=$(cat /run/secrets/codeartifact_token); \
    if [ -z "$TOKEN" ]; then \
        echo "ERROR: codeartifact_token secret is empty" >&2; \
        exit 1; \
    fi; \
    REGISTRY_HOST="${AWS_CODEARTIFACT_DOMAIN}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com"; \
    REGISTRY_PATH="//${REGISTRY_HOST}/npm/${CODEARTIFACT_REPO}/"; \
    REGISTRY_URL="https:${REGISTRY_PATH}"; \
    echo "Configuring npm for CodeArtifact:"; \
    echo "  Domain: ${AWS_CODEARTIFACT_DOMAIN}"; \
    echo "  Account: ${AWS_ACCOUNT_ID}"; \
    echo "  Region: ${AWS_REGION}"; \
    echo "  Repo: ${CODEARTIFACT_REPO}"; \
    echo "  Registry: ${REGISTRY_URL}"; \
    npm config set registry "${REGISTRY_URL}"; \
    npm config set "${REGISTRY_PATH}:_authToken" "${TOKEN}"; \
    npm ci

# Copy application code
COPY . .

# Build TypeScript
RUN npm run build

# Run the application
CMD ["node", "dist/index.js"]
