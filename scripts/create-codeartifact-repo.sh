#!/usr/bin/env bash
set -euo pipefail

# Defaults match mise.local.toml — override via env
AWS_PROFILE="${AWS_PROFILE:-pulumi-dev-sandbox}"
AWS_REGION="${AWS_REGION:-us-west-2}"
DOMAIN="${AWS_CODEARTIFACT_DOMAIN:-posetest}"
REPO="${CODEARTIFACT_REPO:-pose-repo}"
DOMAIN_OWNER="${AWS_ACCOUNT_ID:-}"
AWS_PAGER="${AWS_PAGER:-false}"

export AWS_PROFILE AWS_REGION AWS_PAGER

echo "Ensuring CodeArtifact domain: ${DOMAIN}"
if ! aws codeartifact describe-domain --domain "$DOMAIN"  &>/dev/null; then
  aws codeartifact create-domain \
    --domain "$DOMAIN"
  echo "Created domain ${DOMAIN}"
else
  echo "Domain ${DOMAIN} already exists"
fi

echo "Ensuring CodeArtifact repository: ${REPO}"
if ! aws codeartifact describe-repository \
  --domain "$DOMAIN" --repository "$REPO" &>/dev/null; then
  aws codeartifact create-repository \
    --domain "$DOMAIN" --repository "$REPO" \
    --description "npm packages for docker-build repro"
  echo "Created repository ${REPO}"
else
  echo "Repository ${REPO} already exists"
fi

# Needed so npm can resolve public packages (express, typescript, etc.) via CodeArtifact
echo "Ensuring public:npmjs upstream on ${REPO}"
aws codeartifact associate-external-connection \
  --domain "$DOMAIN" \
  --repository "$REPO" \
  --external-connection public:npmjs &>/dev/null \
  || echo "Upstream public:npmjs already associated (or not needed)"

echo "Done."
echo "  Domain: ${DOMAIN}"
echo "  Repo:   ${REPO}"
echo "  Region: ${AWS_REGION}"
