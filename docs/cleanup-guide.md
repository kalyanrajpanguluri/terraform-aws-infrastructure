# Cleanup guide

The core foundation is persistent. The data pipeline is temporary.

## Core foundation

Do not destroy the root Terraform configuration. It manages the existing VPC, security groups, S3 application bucket, GitHub OIDC resources and CloudTrail resources. Some resources have explicit deletion protection.

## Temporary pipeline

Only clean up the isolated Terraform root:

`environments/dev-pipeline-temp`

Before cleanup:

1. Confirm the current AWS account and region.
2. Confirm the selected backend key is `terraform/project/data-pipeline-temp.tfstate`.
3. Capture final evidence and required data.
4. Inspect S3 objects and versions in all three pipeline buckets.
5. Generate a saved destroy plan.
6. Review every resource action and confirm no core resources appear.

Do not run `terraform destroy` against the repository root. Do not destroy the backend bucket. Do not apply a destroy plan without explicit approval.

Because the pipeline S3 buckets use `force_destroy = true`, a destroy can permanently remove their contents. Export any data that must be retained before approving cleanup.
