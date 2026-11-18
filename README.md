# Terraform AWS Infrastructure

Terraform-managed AWS foundation and a separately managed temporary S3-to-Athena data pipeline in `ap-south-1`.

## Project layers

| Layer | Terraform root | Remote state key |
|---|---|---|
| Persistent foundation | Repository root | `terraform/project/terraform.tfstate` |
| Temporary data pipeline | `environments/dev-pipeline-temp` | `terraform/project/data-pipeline-temp.tfstate` |
| Backend bootstrap | `bootstrap/` | Local state until backend is available |

## Architecture

- Core: VPC, security groups, S3 application storage, GitHub Actions OIDC and CloudTrail.
- Pipeline: S3 raw ingestion, EventBridge, Lambda validation, Step Functions, Glue ETL, Glue crawler/Data Catalog, Athena and CloudWatch.
- Redshift is excluded.

See [architecture](docs/architecture.md), [deployment guide](docs/deployment-guide.md), [recovery guide](docs/recovery-guide.md) and [cleanup guide](docs/cleanup-guide.md).

## Repository layout

```text
bootstrap/                         # S3 backend bootstrap (local state)
docs/                              # Deployment, recovery, architecture and cleanup
environments/dev-pipeline-temp/    # Isolated temporary pipeline Terraform root
modules/                           # Reusable core infrastructure modules
test-data/                         # Small repeatable pipeline test input
.github/workflows/                 # Terraform validation and plan workflow
```

## Important safety rules

- Confirm AWS account and region before Terraform operations.
- Inspect a saved plan before every apply.
- Never apply an unreviewed plan.
- Never destroy the repository-root foundation.
- Keep Terraform state, plans, credentials and private keys out of Git.
- The existing backend bucket and state objects are prerequisites for initializing the existing roots.

## Current project status

The original temporary pipeline was deployed and successfully tested end-to-end. Its test processed three JSON records into Parquet, cataloged the output and queried all three records through Athena. Deployment evidence was collected separately in CloudShell and is not represented as live AWS state by this repository.

For full setup and recovery instructions, start with [the deployment guide](docs/deployment-guide.md).
