# Deployment Workflow Guide

## Overview

The deployment system is now modularized into separate workflows for better maintainability and flexibility.

## Structure

```
.github/
├── workflows/
│   ├── DEPLOYMENT_WORKFLOW_PUBLIC_REPO.yml  # Main router (routes to appropriate workflow)
│   ├── backend-deployment.yml                # Backend-only deployment
│   └── frontend-deployment.yml               # Frontend-only deployment
├── actions/
│   ├── setup-environment/                   # Environment configuration
│   ├── detect-changes/                      # Change detection logic
│   ├── setup-gcp/                           # GCP authentication
│   └── setup-db-credentials/                # Database credentials setup
└── scripts/
    └── function-helpers.sh                  # Helper functions for function deployment
```

## Usage from Private Repository

### Option 1: Using Repository Dispatch (Recommended)

Trigger deployments from your private repository using GitHub API:

#### Full Deployment (Backend + Frontend)
```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/jktech-training/skill-matrix-deploy/dispatches \
  -d '{
    "event_type": "trigger-from-private",
    "client_payload": {
      "repository": "jktech-training/skill-matrix-V2",
      "ref": "development",
      "deployment_type": "full"
    }
  }'
```

#### Backend Only
```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/jktech-training/skill-matrix-deploy/dispatches \
  -d '{
    "event_type": "trigger-from-private",
    "client_payload": {
      "repository": "jktech-training/skill-matrix-V2",
      "ref": "development",
      "deployment_type": "backend"
    }
  }'
```

#### Frontend Only
```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/jktech-training/skill-matrix-deploy/dispatches \
  -d '{
    "event_type": "trigger-from-private",
    "client_payload": {
      "repository": "jktech-training/skill-matrix-V2",
      "ref": "development",
      "deployment_type": "frontend"
    }
  }'
```

### Option 2: Direct Workflow Triggers

You can also trigger specific workflows directly:

- **Full Deployment**: `deploy-full`
- **Backend Only**: `deploy-backend`
- **Frontend Only**: `deploy-frontend`

## Deployment Types

### `deployment_type` Values:

- **`full`** (default): Deploys both backend and frontend
- **`backend`**: Deploys only backend Cloud Functions
- **`frontend`**: Deploys only frontend to Cloud Run

## Workflow Details

### Main Router (`DEPLOYMENT_WORKFLOW_PUBLIC_REPO.yml`)
- Routes requests to appropriate workflow based on `deployment_type`
- Handles repository and branch extraction
- For `full` deployments: Triggers both backend and frontend workflows **in parallel** for faster deployment
- ~68 lines

### Backend Deployment (`backend-deployment.yml`)
- Detects changes in `backend/` directory
- Deploys only changed Cloud Functions
- Uses helper scripts for function detection
- Can be triggered independently or as part of full deployment
- ~200 lines

### Frontend Deployment (`frontend-deployment.yml`)
- Detects changes in `frontend/` directory
- Builds Docker image with build args
- Deploys to Cloud Run
- Can be triggered independently or as part of full deployment
- ~122 lines

## Benefits

1. **Modularity**: Each workflow has a single responsibility
2. **Reusability**: Workflows can be called independently
3. **Maintainability**: Easier to update individual components
4. **Flexibility**: Deploy only what you need
5. **Parallel Execution**: Full deployments run backend and frontend in parallel for faster deployment
6. **Testability**: Test workflows independently

## Migration Notes

- The old monolithic workflow is replaced with this modular structure
- All functionality is preserved
- Backward compatible with existing triggers (defaults to full deployment)
