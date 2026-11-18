# Disaster recovery and state recovery

## Recovery principles

Terraform configuration and Terraform state serve different purposes:

- Configuration describes the desired infrastructure.
- State records the relationship between Terraform resource addresses and real AWS resources.
- S3 backend versioning provides recoverable object versions, but restoring an old state version must be deliberate.

The core foundation and temporary pipeline use separate state keys in the same S3 backend bucket:

| Layer | State key |
|---|---|
| Core foundation | `terraform/project/terraform.tfstate` |
| Temporary pipeline | `terraform/project/data-pipeline-temp.tfstate` |

## 1. Preserve the backend

The existing backend bucket is:

`terraform-state-155335454656-ap-south-1-20261116`

Before recovery, verify the bucket, versioning, encryption, public-access block and both state objects. Do not delete the bucket or its contents as part of routine cleanup.

If the bucket is missing, recreate the backend using `bootstrap/` and a secure recovery procedure. A newly created empty bucket does not restore Terraform state.

## 2. Restore a state object

Use the S3 console or AWS CLI to inspect object versions. Identify the last known-good version for the exact state key. Preserve a copy of the current object before restoring an earlier version.

Never copy a state file from one key into the other. Never edit state JSON manually unless following a controlled Terraform state-repair procedure with a backup.

After restoration, initialize the matching Terraform root and inspect state:

```bash
terraform init
terraform state list
terraform plan -out=recovery-review.tfplan
terraform show recovery-review.tfplan
```

A restored state may be stale relative to AWS. Review refresh results and the full plan. Do not apply until unexpected creates, replacements and destroys are understood.

## 3. If state is lost but infrastructure still exists

Do not run `terraform apply` against an empty state. Terraform may propose creating duplicate resources or fail on globally unique names.

Instead:

1. Preserve the current configuration and collect live AWS resource identifiers.
2. Create a new empty state only in the correct backend key.
3. Import each existing managed resource into its exact Terraform resource address.
4. Run `terraform plan` and reconcile configuration drift.
5. Apply only after the plan shows the intended, reviewed changes.

Import is resource-specific. Follow Terraform import documentation for each resource type and module address.

## 4. If the AWS account is unavailable

GitHub source does not contain AWS credentials, KMS key material, S3 object data, CloudTrail history, or the remote Terraform state. Recovery into another account requires new credentials, new account-specific identifiers, and reviewed configuration changes. Encrypted data recovery may require access to the original KMS keys.

## 5. Never commit these items

- Terraform state or state backups.
- Saved Terraform plans.
- AWS credentials, access keys, session tokens or private SSH keys.
- Secret variable files.
- Unredacted logs containing credentials or sensitive customer data.

Store state backups and evidence in an approved encrypted location with restricted access.
