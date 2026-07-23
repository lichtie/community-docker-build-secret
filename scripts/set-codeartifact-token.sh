# Source this script so exports persist in your shell:
#   source ./scripts/set-codeartifact-token.sh

AWS_PROFILE="${AWS_PROFILE:-pulumi-dev-sandbox}"
AWS_REGION="${AWS_REGION:-us-west-2}"
DOMAIN="${AWS_CODEARTIFACT_DOMAIN:-posetest}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-616138583583}"
# Token lifetime: 15m–12h (default 12h). Use seconds.
DURATION="${CODEARTIFACT_TOKEN_DURATION:-3600}"
AWS_PAGER="${AWS_PAGER:-false}"
export AWS_PROFILE AWS_REGION AWS_PAGER

TOKEN=$(aws codeartifact get-authorization-token \
  --domain "$DOMAIN" \
  --duration-seconds "$DURATION" \
  --query authorizationToken \
  --output text)

export CODEARTIFACT_AUTH_TOKEN="$TOKEN"

echo "CODEARTIFACT_AUTH_TOKEN set (expires in ~${DURATION}s)"
