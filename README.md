# supabase-backend

Bootstrap repository for ONYX-12 setup.

## CI/CD Baseline

This repository uses GitHub Actions for the ONYX-14 delivery controls:

- `CI` runs on every pull request and every push to `main`
- `Deploy Staging` runs automatically after successful CI on merges to `main`
- `Deploy Production` is manual and requires two distinct GitHub collaborator approvals recorded in GitHub before deployment continues
- `Rollback` is manual and records an auditable rollback manifest for every run

## Runtime Secrets

Deployments never hardcode secrets in the repository. Runtime injection is expected through GitHub Secrets:

- `STAGING_DEPLOY_COMMAND`
- `PROD_DEPLOY_COMMAND`
- `ROLLBACK_COMMAND`

If one of those secrets is not configured yet, the workflow records an audited dry run instead of executing a real deployment command.

## Production Approval Gate

Production deployments open a GitHub approval issue for the workflow run and wait for two distinct collaborator approvals.

Rules:

- the person who starts the deploy cannot count as an approver
- each approver must have `write`, `maintain`, or `admin` access to the repository
- each approver must comment `/approve`
- `/deny` from either named approver fails the workflow
- the approval issue is closed automatically when the workflow ends

This keeps approvals written, retained, and auditable inside GitHub.

## Rollback Procedure

1. Open the `Rollback` workflow in GitHub Actions.
2. Choose the environment and target Git ref to restore.
3. Provide the reason for the rollback.
4. Run the workflow.
5. If `ROLLBACK_COMMAND` is configured, GitHub Actions executes it at runtime.
6. Download the generated rollback artifact and confirm the rollback target, operator, and reason.

The CI workflow also runs a rollback smoke test so the rollback manifest path is continuously validated.
