# Deployment guide

This repository contains two independently managed Terraform roots:

- Repository root: the persistent core foundation.
- `environments/dev-pipeline-temp`: the temporary data pipeline.

The pipeline has already been deployed and tested in AWS account `155335454656`, region `ap-south-1`. Do not redeploy it just to validate this documentation.

## 1. Prerequisites

- AWS CLI configured with an authorized IAM Identity Center session.
- Terraform version satisfying the root `versions.tf` constraint.
- Access to the target AWS account and region.
- Git checkout of this repository.

Confirm identity and region before any Terraform operation:

```bash
export AWS_DEFAULT_REGION=ap-south-1
export AWS_PAGER=""
aws sts get-caller-identity
```

Do not use the root AWS account identity for routine deployment. Use the approved deployment role or IAM Identity Center permission set.

## 2. Backend bootstrap

The existing project uses S3 bucket `terraform-state-155335454656-ap-south-1-20261116`. If it still exists and its state objects are intact, do not run bootstrap to recreate it.

For a genuinely new account or a lost backend, use the separate `bootstrap/` Terraform root. It uses local state so it can create the remote state bucket before other Terraform roots are initialized.

```bash
cd bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform show bootstrap.tfplan
```

Review the saved plan. Only apply after confirming it creates the intended new bucket and changes nothing unrelated:

```bash
terraform apply bootstrap.tfplan
terraform output
```

Keep the bootstrap state file secure. Back it up separately. Do not commit it.

If adopting an already-existing bucket, do not run this create plan. Import the bucket and its separately managed configuration resources into the bootstrap state only after reviewing the live bucket and its ownership. Never overwrite or delete an existing state bucket.

## 3. Core foundation

The root backend is configured in `backend.tf` with key `terraform/project/terraform.tfstate`.

For the original account, the backend bucket is already defined in the source. Confirm that it exists and that the current identity can read/write the state and lock object before initialization.

```bash
cd ..
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=core.tfplan
terraform show core.tfplan
```

The plan must be reviewed before applying. Existing resources should be imported into state or restored from a valid state backup before applying. Do not apply a plan that proposes recreating existing resources, replacing protected resources, or deleting foundation resources.

## 4. Temporary data pipeline

The pipeline has a separate S3 backend key:

`terraform/project/data-pipeline-temp.tfstate`

Its resources are isolated from the core root. Initialize and validate from its directory:

```bash
cd environments/dev-pipeline-temp
terraform init
terraform fmt -check
terraform validate
terraform plan -out=pipeline.tfplan
terraform show pipeline.tfplan
```

Only apply after reviewing the saved plan and confirming it affects only the temporary pipeline resources.

## 5. End-to-end test

The sample newline-delimited JSON file is in `test-data/pipeline-test.json`. Upload it to the raw bucket under the `raw/` prefix, for example:

```bash
aws s3 cp ../../test-data/pipeline-test.json s3://<raw-bucket>/raw/pipeline-test.json
```

Expected flow:

1. S3 emits an Object Created event to EventBridge.
2. EventBridge starts the Step Functions state machine.
3. Lambda validates the raw prefix and JSON suffix.
4. Step Functions runs the Glue ETL job synchronously.
5. Glue writes Parquet to the curated bucket.
6. Step Functions starts and polls the Glue crawler.
7. The crawler updates the Glue Data Catalog.
8. Athena queries the catalog table using the dedicated workgroup.

Verify the Step Functions execution, Glue job run, crawler status, curated Parquet object and Athena query results. The successful original test processed three records.

## 6. Account portability

The current source is tied to the original AWS account and region. Before deploying into another account:

- Review account IDs, account-specific IAM/KMS ARNs and fixed resource names.
- Review the GitHub OIDC owner/repository identity and branch conditions.
- Confirm global S3 bucket names are unique.
- Review the SSH ingress CIDR default.
- Update both backend configurations to the new state bucket and preserve separate state keys.
- Review all planned actions before applying.

Do not perform a blind text replacement across Terraform files. Review each account-specific reference in context.
