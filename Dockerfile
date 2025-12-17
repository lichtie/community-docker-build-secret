FROM node:20-slim

# Build arguments for non-sensitive configuration
# These are fine as ARGs because they don't change frequently
ARG AWS_CODEARTIFACT_DOMAIN
ARG AWS_ACCOUNT_ID
ARG AWS_REGION

WORKDIR /app

# Copy package files
COPY package*.json ./

# Use BuildKit secret mount for the CodeArtifact token
# This does NOT affect the build cache - only the actual code/dependencies do
# The secret is mounted at build time but never stored in the image
RUN --mount=type=secret,id=codeartifact_token \
    if [ -f /run/secrets/codeartifact_token ]; then \
        TOKEN=$(cat /run/secrets/codeartifact_token); \
        echo "==========================================="; \
        echo "Simulating CodeArtifact authentication:"; \
        echo "  Domain: ${AWS_CODEARTIFACT_DOMAIN}"; \
        echo "  Account: ${AWS_ACCOUNT_ID}"; \
        echo "  Region: ${AWS_REGION}"; \
        echo "  Token: [REDACTED - from secret mount]"; \
        echo "==========================================="; \
        echo "In a real scenario, this would configure npm:"; \
        echo "  npm config set registry https://${AWS_CODEARTIFACT_DOMAIN}-${AWS_ACCOUNT_ID}.d.codeartifact.${AWS_REGION}.amazonaws.com/npm/my-repo/"; \
        echo "  npm config set //.../:_authToken \$TOKEN"; \
        echo "But for this reproduction, we'll use the public npm registry"; \
    else \
        echo "No CodeArtifact token provided, using default npm registry"; \
    fi

# Install dependencies
RUN npm ci

# Copy application code
COPY . .

# Build TypeScript
RUN npm run build

# Run the application
CMD ["node", "dist/index.js"]
