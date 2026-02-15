# Setting Up GitHub Secrets and Environment Variables

This guide explains how to configure the secrets and environment variables used in the deployment workflow.

## GitHub Secrets Setup

GitHub Secrets are stored securely in your repository settings and are used to pass sensitive information to your workflows.

### How to Add Secrets:

1. Go to your GitHub repository
2. Click on **Settings** (top menu)
3. In the left sidebar, click on **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret with its name and value

### Required Secrets for This Workflow:

#### 1. `PRIVATETOKENPULL`
- **Purpose**: Personal Access Token (PAT) to pull code from the **private repositories** that trigger this workflow
- **Important**: 
  - This workflow runs in the **PUBLIC repository**, but needs to checkout code from **PRIVATE repositories**
  - The workflow supports multiple private repositories:
    - `jktech-training/skill-matrix-V2` (default)
    - `jktech-training/skill-matrix`
  - The token must be created by a user who has **read access to BOTH private repositories**
  - The token must be stored as a secret in the **PUBLIC repository** (where this workflow file is located)
  - The workflow uses `github.event.client_payload.repository` to determine which private repo to checkout
- **How to create** (Fine-grained Token - Recommended):
  1. Go to GitHub → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate new token
  2. **Token name**: Give it a descriptive name (e.g., "Public Repo - Pull from Private Repos")
  3. **Expiration**: Set your preferred expiration date
  4. **Repository access**: Select **"Only select repositories"** and add:
     - `jktech-training/skill-matrix-V2`
     - `jktech-training/skill-matrix`
  5. **Repository permissions** → Click "+ Add permissions" and select:
     - **Contents**: Set to **Read** (this allows reading/cloning repository code)
  6. Click **"Generate token"**
  7. Copy the token value immediately (you won't be able to see it again)
  8. **Store it in the PUBLIC repo's secrets**:
     - Go to the **PUBLIC repository**: `jktech-training/skill-matrix-deploy`
     - Navigate to: **Settings** → **Secrets and variables** → **Actions**
     - Click **"New repository secret"** (in the "Repository secrets" section)
     - **Name**: `PRIVATETOKENPULL` (must match exactly)
     - **Value**: Paste the token you copied
     - Click **"Add secret"**
     - ⚠️ **Important**: Store it in the PUBLIC repo, NOT in the private repos

- **Alternative: Classic Token**:
  - Go to GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
  - Generate new token (classic)
  - Select `repo` scope (this gives full repository access)
  - Copy the token value
  - **Store it in the PUBLIC repo's secrets**

#### 2. `GCP_SAKEY`
- **Purpose**: Google Cloud Service Account JSON key for authentication
- **You already have the file**: `training-project-419308-4fac03d81a53.json`
- **How to add it to GitHub Secrets**:
  1. Open the JSON file (`training-project-419308-4fac03d81a53.json`)
  2. **Copy the ENTIRE JSON content** (all lines, including the opening `{` and closing `}`)
  3. Go to your PUBLIC repository: `jktech-training/skill-matrix-deploy`
  4. Navigate to: **Settings** → **Secrets and variables** → **Actions**
  5. Click **"New repository secret"** (in the "Repository secrets" section)
  6. **Name**: `GCP_SAKEY` (must match exactly)
  7. **Value**: Paste the entire JSON content (it should be one long string)
  8. Click **"Add secret"**
- **Important Notes**:
  - The JSON must be pasted as a single string (all on one line or with newlines preserved)
  - The workflow expects the complete JSON object
  - ⚠️ **Security**: This file contains sensitive credentials - never commit it to git or share it publicly
  - After adding to GitHub, you can safely delete the local file if desired (GitHub stores it securely)

#### 3. Database Secrets
These are used when deploying Cloud Functions. **Each secret contains all database credentials in key=value format:**

**`DB_PROD`** - For `jktech-training/skill-matrix` main branch (production)
- **Format**: Key-value pairs, one per line
- **Example content**:
  ```
  DB_HOST=34.47.204.166
  DB_USER=postgres
  DB_PASS=Skillmatrix@123
  DB_NAME=Skill_Matrix
  DB_SCHEMA=skill-matrix-prod
  DB_PORT=5432
  BASE_URL=https://asia-south1-training-project-419308.cloudfunctions.net/
  SEND_EMAIL_URL=https://asia-south1-training-project-419308.cloudfunctions.net/send_mail
  APP_URL=https://skill-matrix-140475459295.asia-south1.run.app/
  EMAIL_TEMPLATE=<!doctypehtml><html lang=en><meta charset=UTF-8><meta content='width=device-width,initial-scale=1'name=viewport><style>body{font-family:Arial,sans-serif;background-color:#f6f8fa;margin:0;padding:0;color:#333}.container{max-width:600px;margin:40px auto;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)}.header{background:linear-gradient(to right,#1e40af,#2563eb,#3b82f6);color:#fff;padding:16px 24px;font-size:20px;font-weight:700;text-align:center}.content{padding:24px;line-height:1.6;background-color:#fff;color:#333}.content ul{padding-left:20px;margin-top:8px}.content li{margin-bottom:6px}.button{display:inline-block;margin-top:16px;padding:8px 16px;font-size:14px;color:#fff;background-color:#2563eb;text-decoration:none;border-radius:6px;text-align:center}.footer{padding:16px 24px;background-color:#f1f3f4;font-size:14px;color:#555;text-align:center}.footer strong{color:#202124}@media (prefers-color-scheme:dark){body{background-color:#1a1a1a!important;color:#e0e0e0!important}.container{box-shadow:0 2px 8px rgba(255,255,255,.05)}.header{background:linear-gradient(to right,#4b5563,#1f2937,#111827);color:#e0e0e0!important}.content{background-color:#2a2a2a;color:#e0e0e0}.button{background-color:#4f46e5;color:#fff!important}.footer{background-color:#333!important;color:#aaa!important}.footer strong{color:#fff!important}}</style><div class=container><div class=header>Skill Review Request</div><div class=content><p>Dear Manager,<p>The following skill(s) have been requested for review by <strong>{{requestee_name}}</strong>:<ul>{{requested_skills}}</ul><p>Please review and take the necessary action.<p><a class=button href={{skill_matrix_url}}>Go to Skill Matrix</a><p>Regards,<br><strong>Skill Matrix Review System</strong></div><div class=footer>This is an automated email. Please do not reply.</div></div>
  OPENAI_API_KEY=sk-proj-your-openai-api-key-here
  ```

**`DB_DEV`** - For `jktech-training/skill-matrix` development branch
- **Format**: Key-value pairs, one per line
- **Example content**:
  ```
  DB_HOST=34.47.204.166
  DB_USER=postgres
  DB_PASS=Skillmatrix@123
  DB_NAME=Skill_Matrix
  DB_SCHEMA=skill-matrix-dev
  DB_PORT=5432
  BASE_URL=https://asia-south1-training-project-419308.cloudfunctions.net/
  SEND_EMAIL_URL=https://asia-south1-training-project-419308.cloudfunctions.net/send_mail
  APP_URL=https://skill-matrix-140475459295.asia-south1.run.app/
  EMAIL_TEMPLATE=<!doctypehtml><html lang=en><meta charset=UTF-8><meta content='width=device-width,initial-scale=1'name=viewport><style>body{font-family:Arial,sans-serif;background-color:#f6f8fa;margin:0;padding:0;color:#333}.container{max-width:600px;margin:40px auto;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)}.header{background:linear-gradient(to right,#1e40af,#2563eb,#3b82f6);color:#fff;padding:16px 24px;font-size:20px;font-weight:700;text-align:center}.content{padding:24px;line-height:1.6;background-color:#fff;color:#333}.content ul{padding-left:20px;margin-top:8px}.content li{margin-bottom:6px}.button{display:inline-block;margin-top:16px;padding:8px 16px;font-size:14px;color:#fff;background-color:#2563eb;text-decoration:none;border-radius:6px;text-align:center}.footer{padding:16px 24px;background-color:#f1f3f4;font-size:14px;color:#555;text-align:center}.footer strong{color:#202124}@media (prefers-color-scheme:dark){body{background-color:#1a1a1a!important;color:#e0e0e0!important}.container{box-shadow:0 2px 8px rgba(255,255,255,.05)}.header{background:linear-gradient(to right,#4b5563,#1f2937,#111827);color:#e0e0e0!important}.content{background-color:#2a2a2a;color:#e0e0e0}.button{background-color:#4f46e5;color:#fff!important}.footer{background-color:#333!important;color:#aaa!important}.footer strong{color:#fff!important}}</style><div class=container><div class=header>Skill Review Request</div><div class=content><p>Dear Manager,<p>The following skill(s) have been requested for review by <strong>{{requestee_name}}</strong>:<ul>{{requested_skills}}</ul><p>Please review and take the necessary action.<p><a class=button href={{skill_matrix_url}}>Go to Skill Matrix</a><p>Regards,<br><strong>Skill Matrix Review System</strong></div><div class=footer>This is an automated email. Please do not reply.</div></div>
  OPENAI_API_KEY=sk-proj-your-openai-api-key-here
  ```

**`DB_DEV_V2`** - For `jktech-training/skill-matrix-V2` development branch
- **Format**: Key-value pairs, one per line
- **Example content**:
  ```
DB_HOST=34.47.204.166
DB_USER=postgres
DB_PASS=Skillmatrix@123
DB_NAME=Skill_Matrix
DB_SCHEMA=skill_matrix_v2_dev
DB_PORT=5432
BASE_URL=https://asia-south1-training-project-419308.cloudfunctions.net/
SEND_EMAIL_URL=https://asia-south1-training-project-419308.cloudfunctions.net/send_mail
APP_URL=https://skill-matrix-140475459295.asia-south1.run.app/
EMAIL_TEMPLATE=<!doctypehtml><html lang=en><meta charset=UTF-8><meta content='width=device-width,initial-scale=1'name=viewport><style>body{font-family:Arial,sans-serif;background-color:#f6f8fa;margin:0;padding:0;color:#333}.container{max-width:600px;margin:40px auto;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)}.header{background:linear-gradient(to right,#1e40af,#2563eb,#3b82f6);color:#fff;padding:16px 24px;font-size:20px;font-weight:700;text-align:center}.content{padding:24px;line-height:1.6;background-color:#fff;color:#333}.content ul{padding-left:20px;margin-top:8px}.content li{margin-bottom:6px}.button{display:inline-block;margin-top:16px;padding:8px 16px;font-size:14px;color:#fff;background-color:#2563eb;text-decoration:none;border-radius:6px;text-align:center}.footer{padding:16px 24px;background-color:#f1f3f4;font-size:14px;color:#555;text-align:center}.footer strong{color:#202124}@media (prefers-color-scheme:dark){body{background-color:#1a1a1a!important;color:#e0e0e0!important}.container{box-shadow:0 2px 8px rgba(255,255,255,.05)}.header{background:linear-gradient(to right,#4b5563,#1f2937,#111827);color:#e0e0e0!important}.content{background-color:#2a2a2a;color:#e0e0e0}.button{background-color:#4f46e5;color:#fff!important}.footer{background-color:#333!important;color:#aaa!important}.footer strong{color:#fff!important}}</style><div class=container><div class=header>Skill Review Request</div><div class=content><p>Dear Manager,<p>The following skill(s) have been requested for review by <strong>{{requestee_name}}</strong>:<ul>{{requested_skills}}</ul><p>Please review and take the necessary action.<p><a class=button href={{skill_matrix_url}}>Go to Skill Matrix</a><p>Regards,<br><strong>Skill Matrix Review System</strong></div><div class=footer>This is an automated email. Please do not reply.</div></div>
OPENAI_API_KEY=sk-proj-your-openai-api-key-here
  ```

**How to add these secrets:**
1. Go to: Repository Settings → Secrets and variables → Actions → New repository secret
2. **Name**: `DB_PROD` (or `DB_DEV` or `DB_DEV_V2`)
3. **Value**: Paste all the key-value pairs (one per line, as shown in examples above)
4. Click "Add secret"
5. Repeat for the other two secrets

**Important Notes:**
- ✅ **No JSON needed** - Just use key=value format, one per line
- ✅ Each secret contains all database credentials and required environment variables
- ✅ **OPENAI_API_KEY is required** - Make sure to include it in all DB secrets (DB_PROD, DB_DEV, and DB_DEV_V2)
- ✅ The workflow automatically parses these and extracts individual values
- ✅ The workflow automatically detects required environment variables from your code (like OPENAI_API_KEY)
- ✅ The workflow selects the correct secret based on repository and branch:
  - `jktech-training/skill-matrix` + `main` → uses `DB_PROD`
  - `jktech-training/skill-matrix` + development → uses `DB_DEV`
  - `jktech-training/skill-matrix-V2` + development → uses `DB_DEV_V2`
- ⚠️ **If OPENAI_API_KEY is missing from your DB secret**, you can also add it as a separate GitHub secret named `OPENAI_API_KEY` as a fallback

### Accessing Secrets in Workflow:

Secrets are accessed using:
```yaml
${{ secrets.SECRET_NAME }}
```

Example from your workflow:
```yaml
token: ${{ secrets.PRIVATETOKENPULL }}
credentials_json: '${{ secrets.GCP_SAKEY }}'
```

## Environment Variables in Workflow

### How They Work:

Environment variables are set in workflow steps using:
```bash
echo "VAR_NAME=value" >> $GITHUB_ENV
```

They can then be accessed in:
- **YAML expressions**: `${{ env.VAR_NAME }}`
- **Bash scripts**: `$VAR_NAME` or `${VAR_NAME}`

### Environment Variables Set in This Workflow:

#### Set in "Determine Environment" step:
- `BRANCH` - Current branch name
- `ENV` - Environment name ("production" or "development")
- `ENV_PREFIX` - Prefix for function names ("" for production, "dev_" for development)
- `CLOUD_RUN_SERVICE` - Cloud Run service name
- `IMAGE_SUFFIX` - Docker image suffix ("-dev" for dev, "" for prod)
- `BUCKET_NAME` - GCS bucket name

#### Set in "Check for Changes" steps:
- `CHANGED_FRONTEND` - "true" or "false"
- `CHANGED_BACKEND` - "true" or "false"

#### Set in "Set Docker Image Name and Tag" step:
- `IMAGE_NAME` - Docker image name
- `TAG` - Image tag (timestamp-based)

### Example Usage:

```yaml
# Setting an environment variable
- name: Set Variable
  run: |
    echo "MY_VAR=my_value" >> $GITHUB_ENV

# Using in YAML expression
- name: Use in YAML
  if: env.MY_VAR == 'my_value'
  run: echo "Variable is set"

# Using in bash script
- name: Use in Bash
  run: |
    echo "Value is: $MY_VAR"
    echo "Or: ${MY_VAR}"
```

## Shell Variables

These are temporary variables set within bash scripts and only exist within that script's scope:

```bash
BASE_SHA=$(git merge-base origin/${{ env.BRANCH }} HEAD)
CHANGED=$(git diff --name-only $BASE_SHA HEAD)
FUNCTION_NAME="${ENV_PREFIX}${ENTRY_POINT}"
```

## Multiple Source Repositories

This workflow supports multiple private repositories as source:

- `jktech-training/skill-matrix-V2` (default fallback)
- `jktech-training/skill-matrix`

### How It Works:

1. **Trigger**: Either private repo can trigger this workflow via `repository_dispatch` event
2. **Repository Selection**: The workflow uses `github.event.client_payload.repository` to determine which repo to checkout
3. **Fallback**: If no repository is specified in the payload, it defaults to `jktech-training/skill-matrix-V2`
4. **Token Requirement**: The `PRIVATETOKENPULL` token must have access to **both** repositories

### Triggering from Private Repos:

When triggering from a private repo, include the repository name in the payload:

```json
{
  "repository": "jktech-training/skill-matrix",
  "ref": "main"
}
```

Or:

```json
{
  "repository": "jktech-training/skill-matrix-V2",
  "ref": "main"
}
```

## Troubleshooting

### Secrets Not Working?
- Ensure secrets are set in the correct repository
- Check that secret names match exactly (case-sensitive)
- Verify the secret values are correct (no extra spaces)

### Environment Variables Not Available?
- Make sure the step that sets the variable runs before the step that uses it
- Use `${{ env.VAR_NAME }}` in YAML, `$VAR_NAME` in bash
- Check that `$GITHUB_ENV` is used correctly (not `$GITHUB_OUTPUT`)

### Viewing Variables During Workflow:
Add a debug step:
```yaml
- name: Debug Variables
  run: |
    echo "ENV: ${{ env.ENV }}"
    echo "BRANCH: ${{ env.BRANCH }}"
    # Note: Secrets cannot be printed for security reasons
```
