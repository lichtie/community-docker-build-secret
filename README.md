# Docker Build with Fresh Secrets on Config Changes

This Pulumi program demonstrates how to use the Stash resource with replacement triggers to ensure Docker images get fresh CodeArtifact tokens whenever the image configuration changes, without triggering rebuilds when only the token changes.

## How It Works

### The Problem

CodeArtifact tokens are short-lived and change on each `pulumi up` run. We want to:

- ✅ Use fresh tokens when rebuilding images for other reasons (tag changes, buildArg changes, etc.)
- ❌ Avoid triggering image rebuilds when ONLY the token changes

### The Solution

1. **Image Configuration**: All Docker image inputs (buildArgs, tags, context, etc.) are defined in a single `imageConfig` object for maintainability.

2. **Replacement Trigger**: A trigger value `imageConfig` changes whenever any configuration input changes.

3. **Stash Resource**: A `pulumi.Stash` stores the CodeArtifact token with:

   - `replacementTrigger`: Set to `imageConfig` - causes the Stash to replace when config changes
   - `ignoreChanges: ["input"]`: Prevents the Stash from updating when the token value changes

4. **Image Build**: The Docker image uses the token from the Stash as a build arg, ensuring it gets the fresh token whenever the Stash is replaced.

### Key Features

- **Stable across runs**: Running `pulumi up` multiple times without config changes won't rebuild the image, even though the token changes each run
- **Fresh tokens on config changes**: Changing tags, buildArgs, or other config triggers the Stash to replace with a fresh token, which cascades to rebuilding the image
- **Secret handling**: The token is marked as a secret throughout the pipeline using `pulumi.secret()`
- **Verifiable**: The token value passed to the image is exposed in outputs (unsecreted) for testing/debugging

## Testing

### Initial Setup

```bash
cd pulumi
npm install
pulumi stack init dev
```

### Test 1: Initial Deployment

```bash
pulumi up
```

**Expected Result:**

- Creates the `tokenStash` Stash resource
- Creates the `imageFixed` Docker image
- Outputs show the token value that was used

### Test 2: No Changes - Should Be Stable

```bash
pulumi up
```

**Expected Result:**

- No resources to update
- Even though the token value is different (due to `Date.now()`), the Stash and Image are NOT replaced
- Message: "No changes. Your infrastructure is up-to-date."

### Test 3: Change Image Configuration - Should Trigger Rebuild

Edit `index.ts` and modify a tag in `imageConfig.tags`:

```typescript
tags: [
  "docker-build-secret-repro:fixed",
  "docker-build-secret-repro:working",
  "new-tag-here", // Add a new tag
],
```

Then run:

```bash
pulumi up
```

**Expected Result:**

- The `tokenStash` Stash is replaced (because `imageConfig` changed)
- The `imageFixed` Docker image is replaced (because the Stash output changed)
- The new token value is captured and used in the build
- Outputs show the fresh token value

### Test 4: Verify Stability Again

```bash
pulumi up
```

**Expected Result:**

- No resources to update
- The previous token is still being used
- Message: "No changes. Your infrastructure is up-to-date."

### Test 5: Change Build Args - Should Trigger Rebuild

Edit `index.ts` and add/modify a buildArg in `imageConfig.buildArgs`:

```typescript
buildArgs: {
  AWS_CODEARTIFACT_DOMAIN: awsCodeArtifactDomain,
  AWS_ACCOUNT_ID: awsAccountId,
  AWS_REGION: awsRegion,
  NEW_ARG: "some-value", // Add a new build arg
},
```

Then run:

```bash
pulumi up
```

**Expected Result:**

- The `tokenStash` Stash is replaced (because `imageConfig` changed)
- The `imageFixed` Docker image is replaced (because both the Stash output and buildArgs changed)
- A fresh token is captured and used

## Checking the Token Value

After each `pulumi up`, check the outputs:

```bash
pulumi stack output secretsUsed
```

This will show:

- `tokenPreview`: The actual token value passed to the Docker image (unsecreted for verification)
- `domain`: The CodeArtifact domain
- `accountId`: The AWS account ID
- `region`: The AWS region

Compare the `tokenPreview` value across runs to verify:

- It stays the same when only the token source changes
- It updates when config changes trigger a rebuild

## Architecture Diagram

```
awsCodeArtifactToken (changes each run)
         ↓
    tokenStash (Stash)
         ↓ (replacementTrigger: imageConfig)
         ↓ (ignoreChanges: ["input"])
         ↓
    tokenStash.output
         ↓
    imageFixed.buildArgs.CODEARTIFACT_TOKEN
         ↓
    Docker Build
```

## Key Files

- `index.ts`: Main Pulumi program with Stash and Image resources
- `../Dockerfile`: Docker configuration (referenced by the image build)
- `package.json`: Node.js dependencies

## Cleanup

To destroy all resources:

```bash
pulumi destroy
pulumi stack rm dev
```

## Notes

- The token is unsecreted in outputs for testing purposes. In production, you will want to remove or mask this.
- The `imageConfig` object should be updated whenever you need to change image build parameters.
