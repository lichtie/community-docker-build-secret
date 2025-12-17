import * as pulumi from "@pulumi/pulumi";
import * as dockerBuild from "@pulumi/docker-build";

// Simulate AWS CodeArtifact credentials
// In real scenario, these would come from AWS STS and change on each run
const awsCodeArtifactToken =
  process.env.CODEARTIFACT_AUTH_TOKEN || `temp-token-${Date.now()}`;
const awsCodeArtifactDomain =
  process.env.AWS_CODEARTIFACT_DOMAIN || "elisabethtest";
const awsAccountId = process.env.AWS_ACCOUNT_ID || "1234567890";
const awsRegion = process.env.AWS_REGION || "us-east-1";

const imageConfig = {
  context: {
    location: "../",
  },
  dockerfile: {
    location: "../Dockerfile",
  },
  buildArgs: {
    AWS_CODEARTIFACT_DOMAIN: awsCodeArtifactDomain,
    AWS_ACCOUNT_ID: awsAccountId,
    AWS_REGION: awsRegion,
  },
  tags: [
    "docker-build-secret-repro:fixed",
    "docker-build-secret-repro:working",
    // "addme",
  ],
  push: false,
  exports: [
    {
      cacheonly: {},
    },
  ],
};

// Use Stash to store the CodeArtifact token
// The Stash will be replaced whenever the image inputs change (via replacementTrigger)
// This ensures a fresh token is captured whenever we're rebuilding the image anyway
const tokenStash = new pulumi.Stash(
  "codeartifact-token",
  {
    input: pulumi.secret(awsCodeArtifactToken),
  },
  {
    replacementTrigger: imageConfig,
    ignoreChanges: ["input"],
  }
);

// Build the Docker image with CodeArtifact token as a build arg (marked as secret)
// The token comes from the Stash, which refreshes whenever other inputs change
const imageFixed = new dockerBuild.Image("app-image-fixed", {
  ...imageConfig,
  buildArgs: {
    ...imageConfig.buildArgs,
    CODEARTIFACT_TOKEN: pulumi.secret(tokenStash.output),
  },
});

export const imageIdFixed = imageFixed.ref;
export const secretsUsed = {
  tokenPreview: pulumi.unsecret(
    imageFixed.buildArgs.apply((args) => {
      return args ? args["CODEARTIFACT_TOKEN"] : undefined;
    })
  ),
  domain: awsCodeArtifactDomain,
  accountId: awsAccountId,
  region: awsRegion,
};
