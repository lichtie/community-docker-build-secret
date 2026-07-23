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

const codeArtifactRepo = process.env.CODEARTIFACT_REPO || "pose-repo";

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
    CODEARTIFACT_REPO: codeArtifactRepo,
    BUILDKIT_INLINE_CACHE: "1",
  },
  tags: [
    "docker-build-secret-repro:fixed",
    "docker-build-secret-repro:working",
    // "addme",
  ],
  ignoreSecretsInDiffCalculation: ["codeartifact_token"],
  push: false,
  exports: [
    {
      cacheonly: {},
    },
  ],
};

// Pass the token as a BuildKit secret (id=codeartifact_token) so the Dockerfile
// can mount it without baking credentials into image layers / build args.
const imageFixed = new dockerBuild.Image("app-image-fixed", {
  ...imageConfig,
  secrets: {
    codeartifact_token: pulumi.secret(awsCodeArtifactToken),
  },
});

export const imageIdFixed = imageFixed.ref;
export const secretsUsed = {
  tokenPreview: pulumi.unsecret(
    imageFixed.secrets.apply((secrets) => {
      return secrets ? secrets["codeartifact_token"] : undefined;
    })
  ),
  domain: awsCodeArtifactDomain,
  accountId: awsAccountId,
  region: awsRegion,
  repo: codeArtifactRepo,
  imageId: imageFixed.contextHash,
  imageDigest: imageFixed.digest,
};
