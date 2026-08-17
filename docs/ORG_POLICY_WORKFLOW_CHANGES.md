# Workflow changes after GCP org policy (no `allUsers`)

**Repo:** `jktech-training/skill-matrix-deploy`  
**Workflow file:** `.github/workflows/DEPLOYMENT_WORKFLOW_PUBLIC_REPO.yml`  
**Applies to:** Skill Matrix **DEV** and **PROD** (skill-matrix-v2 branches)

This document describes what changed on the **deployment / workflow side** after the org policy blocked new `allUsers` → `roles/run.invoker` bindings. Application code changes live in `skill-matrix-v2` (see that repo’s `docs/deployment/PRIVATE_FUNCTIONS_PROXY_HANDOFF.md`).

---

## 1. Why we changed the workflow

### Problem
- GCP org policy (e.g. `iam.allowedPolicyMemberDomains`) rejects **new** public invoker grants (`allUsers`).
- `gcloud functions deploy --allow-unauthenticated` does two steps: (1) deploy revision, (2) grant `allUsers` invoker.
- Step (1) could succeed while step (2) failed → functions looked “ACTIVE” but returned **403** to browsers.
- Older functions created **before** the policy already had `allUsers`; redeploys looked fine. Newer ones (e.g. report functions created later) never got public invoker.

### What we cannot do
- Org-policy exception for `allUsers` (not approved).
- Add every JKTech Azure AD user as a GCP account.

### Target model (DEV + PROD)
```
JKTech user (Azure AD)
  → Microsoft SSO (jktech-auth-gateway)
  → Frontend Cloud Run (public SPA URL; app-level SSO)
       server.mjs validates SSO JWT + attaches Google ID token
  → Cloud Functions (private; invoker = frontend runtime SA only)
```

Users never need GCP identities. Browser never needs `allUsers` on functions.

---

## 2. Environment mapping (DEV vs PROD)

| | **DEV** | **PROD** |
|--|---------|----------|
| **App repo branch** | non-`main` (e.g. `development`) | `main` |
| **Secret for URLs/DB** | `DB_DEV_V2` | `DB_PROD_V2` |
| **Frontend Cloud Run** | `skillmatrix-dev` | `skillmatrix` |
| **Function name prefix** | `dev_` (`ENV_PREFIX=dev_`) | none |
| **Typical region (v2)** | `asia-south1` (default) | `us-central1` (v2 `main` override in workflow) |
| **Artifact Registry** | `skill-matrix` | `skill-matrix-prod` (v2 `main`) |
| **`FUNCTIONS_BASE_URL`** | `{BASE_URL from secret}/dev_` | `{BASE_URL from secret}/` |

`BASE_URL` still comes from the DB_* secret (e.g. `https://asia-south1-training-project-419308.cloudfunctions.net/`).  
For DEV, the workflow appends `dev_` so the proxy targets `dev_get_employee_…` style names while the **browser path stays unprefixed** (`/get_employee_…`).

---

## 3. Workflow changes (what was removed / added)

### 3.1 Frontend build

| Before | After |
|--------|--------|
| Bake absolute `VITE_BASE_URL=https://…cloudfunctions.net/…` into the image | Bake `VITE_BASE_URL=/` (same-origin only) |
| Browser called Cloud Functions directly | Browser calls frontend origin; `server.mjs` proxies |

Still passed at build: `VITE_SSO_URL` (auth gateway).

### 3.2 Frontend Cloud Run deploy

| Before | After |
|--------|--------|
| Deploy image only | Also set runtime env |
| — | `FUNCTIONS_BASE_URL` (from secret `BASE_URL`, + `dev_` on DEV) |
| — | `SSO_VERIFY_URL` (from `VITE_SSO_URL` secret, normalized to `…/verify`) |
| `--allow-unauthenticated` on **frontend** | **Kept** — SPA must load without a GCP login; SSO is Microsoft via gateway |

**Important:** Frontend stays publicly invokable. Only **backend HTTP functions** are private.

### 3.3 Backend HTTP function deploy

| Before | After |
|--------|--------|
| `--allow-unauthenticated` | `--no-allow-unauthenticated` |
| `set_iam_policy` → grant `allUsers` `roles/run.invoker` | `set_frontend_invoker` → grant **frontend Cloud Run SA** `roles/run.invoker` |
| — | Attempt `remove-iam-policy-binding` for `allUsers` (ignore if absent) |
| `--source "$fn_dir"` only | Stage source + copy `backend/utils/` into package |
| — | Set function env `SSO_VERIFY_URL` for gateway JWT verify |

Bucket-triggered functions are unchanged regarding public HTTP invoker (no browser `allUsers` path).

### 3.4 Shared utils packaging

Report (and other) functions import `utils.sso_auth` / `utils.event_publisher`.  
Cloud Functions source is flat, so the workflow:

1. Copies the function folder into a temp dir  
2. Copies `backend/utils/` next to `main.py`  
3. Deploys with `--source` = that staged dir  

If `backend/utils` changes, functions that import `utils.*` are included in the deploy set even when their own folder did not change.

### 3.5 IAM helper behavior (`set_frontend_invoker`)

1. Resolve frontend service SA from Cloud Run (`skillmatrix` / `skillmatrix-dev`), or fall back to `{projectNumber}-compute@developer.gserviceaccount.com`.
2. Remove `allUsers` invoker if present.
3. Add `serviceAccount:<frontend-sa>` → `roles/run.invoker` on the function’s underlying Cloud Run service.

Deploy SA (`GCP_SAKEY`) must be allowed to change IAM on those services.

---

## 4. What did **not** change on the workflow side

- Trigger model: `repository_dispatch` from the private app repo.
- Project: `training-project-419308`.
- Function runtime SA for code execution: `training-project-419308@appspot.gserviceaccount.com` (unchanged).
- DB_* secret selection by repo/branch.
- No changes to `jktech-auth-gateway` (shared SSO product; consume `/login` and `/verify` only).
- No org-policy exception; no per-user GCP accounts.

---

## 5. Required secrets / config

| Secret / config | Role after change |
|-----------------|-------------------|
| `DB_DEV_V2` / `DB_PROD_V2` | Must include `BASE_URL=…` (used as `FUNCTIONS_BASE_URL` upstream) |
| `VITE_SSO_URL` | Auth gateway base (workflow appends `/verify` for `SSO_VERIFY_URL`) |
| `GCP_SAKEY` | Deploy + IAM bind invoker on functions |
| `PRIVATETOKENPULL` | Checkout private skill-matrix-v2 |

Optional (app/runtime only; **never** set in prod for real security bypass):

- `SKIP_SSO_VERIFY` / `SKIP_GOOGLE_ID_TOKEN` (frontend container)  
- `SKIP_SSO_AUTH` (functions)

---

## 6. Rollout rules (DEV and PROD)

### Order
1. Land **skill-matrix-v2** proxy + SSO report auth (app code).  
2. Land **this workflow** in skill-matrix-deploy.  
3. Deploy **DEV** first (`development` + full frontend + backend).  
4. Smoke-test DEV, then **PROD** (`main` + full frontend + backend).

### Why a full backend pass matters
Invoker grants and `allUsers` removal run **per function on deploy**. Functions not redeployed keep old IAM until updated. Prefer `force_deploy=true` / full backend once per environment after this change.

### Smoke checklist (DEV and PROD)
- [ ] App URL loads without GCP login prompt  
- [ ] Microsoft SSO (jktech-auth-gateway) succeeds  
- [ ] Normal screens load (hierarchy, skills, etc.)  
- [ ] All four reports download without Cloud Run **403**  
  - `get_employee_skill_matrix_report`  
  - `get_employee_skills_report`  
  - `get_employee_certificate_report`  
  - `get_employee_training_report`  
  - (DEV names are `dev_…` on GCP; browser paths stay unprefixed)  
- [ ] Direct browser hit to `*.cloudfunctions.net/<function>` returns **403** (expected — private)  
- [ ] Frontend Cloud Run has `FUNCTIONS_BASE_URL` and `SSO_VERIFY_URL` set  

---

## 7. DEV vs PROD — same design, different values

| Concern | DEV | PROD |
|---------|-----|------|
| Public function invoker | **No** | **No** |
| Frontend public URL | **Yes** (`skillmatrix-dev`) | **Yes** (`skillmatrix`) |
| User auth | Azure AD via gateway | Azure AD via gateway |
| Proxy | `server.mjs` on frontend | `server.mjs` on frontend |
| Who can invoke functions | Frontend DEV SA | Frontend PROD SA |
| Function names | `dev_*` | unprefixed |
| Org-policy / `allUsers` | Not used | Not used |

There is **no separate “keep allUsers on DEV” path** in this workflow. Both environments use the private-function + BFF model.

---

## 8. Troubleshooting (workflow-related)

| Symptom | Likely cause | What to check |
|---------|--------------|---------------|
| Frontend up; all APIs 502/500 from proxy | Missing `FUNCTIONS_BASE_URL` | Cloud Run env on `skillmatrix` / `skillmatrix-dev` |
| APIs 401 from proxy | SSO JWT missing/invalid | Login flow; `SSO_VERIFY_URL`; gateway `/verify` |
| APIs 403 from Cloud Functions | Frontend SA lacks `run.invoker` | IAM on function service; redeploy backend; deploy SA permissions |
| Reports 401 from function | `require_sso_bearer` / missing utils package | Function env `SSO_VERIFY_URL`; staged `backend/utils` in deploy logs |
| Deploy fails on IAM bind | Org policy or missing IAM admin on deploy SA | Logs from `set_frontend_invoker`; do **not** fall back to `allUsers` |
| Only some functions work | Partial deploy | Force full backend deploy |

---

## 9. Related documents

- App handoff (skill-matrix-v2): `docs/deployment/PRIVATE_FUNCTIONS_PROXY_HANDOFF.md`  
- Secrets setup (this repo): `SETUP_SECRETS.md`  
- Workflow implementation: `.github/workflows/DEPLOYMENT_WORKFLOW_PUBLIC_REPO.yml`

---

## 10. Summary

After the org policy, the workflow **stopped making HTTP Cloud Functions public**.  
DEV and PROD both deploy:

1. A **public frontend** with same-origin proxy env (`FUNCTIONS_BASE_URL`, `SSO_VERIFY_URL`).  
2. **Private HTTP functions** with invoker only for the frontend runtime service account.  
3. Packaged **`backend/utils`** and **`SSO_VERIFY_URL`** on functions for app-level Azure AD SSO checks.

That keeps Skill Matrix available to all JKTech Azure AD users via existing Microsoft SSO, without org-policy exceptions and without adding users to GCP.
