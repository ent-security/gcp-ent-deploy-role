# gcp-ent-deploy-role

Infrastructure as Code to provision the minimum GCP resources Ent Home needs to deploy tenant infrastructure into a customer-owned GCP project. Supports Terraform / OpenTofu and the `gcloud` CLI.

Analogue of [aws-ent-deploy-role](https://github.com/ent-security/aws-ent-deploy-role) for GCP customers.

## What this module provisions

- A Workload Identity Pool + AWS provider that federates Ent Home's AWS IAM roles into this GCP project.
- A service account (`ent-home-deployer`) that Ent Home impersonates via that federation.
- Two custom IAM roles with enumerated permissions (no `roles/*.admin`):
  - **Unscoped role** — bound unconditionally; covers services whose IAM does not support resource-name conditions (Compute, GKE, Cloud SQL, Memorystore, Certificate Manager, Vertex AI, Service Networking).
  - **Scoped role** — bound seven times with per-service IAM Conditions that restrict the deployer to Ent-prefixed resources (Storage, Secret Manager, Pub/Sub, Artifact Registry, IAM service accounts, Cloud DNS).
- Enablement of the 17 Google APIs Ent Home requires.

## Prerequisites

- A GCP project that already exists, has billing enabled, and that you control as owner.
- Ent's AWS account ID and the set of Home IAM role names. You'll receive these from Ent during onboarding.
- One of: Terraform / OpenTofu 1.3+, or a shell with `gcloud` authenticated as a user with project owner or `iam.roleAdmin` + `resourcemanager.projectIamAdmin` + `iam.workloadIdentityPoolAdmin`.

### About the AWS role names

Ent Home may call into your GCP project from more than one AWS IAM role:

- The **EKS Pod Identity role** the `ent-home-api` pod runs under at runtime. This is the role a deployment actually executes as. Ent will provide the exact name per environment (dev/prod).
- One or more **human-admin roles** (for example `HomeProdAssumeAdmin`) used by Ent operators for manual bootstrap or troubleshooting runs.

All of them must be federated, or deployments will fail with `Permission 'iam.serviceAccounts.getAccessToken' denied` when attempting to impersonate the deployer service account.

## Terraform / OpenTofu usage

**Note**: pin to a specific tag (e.g. `ref=v1.0.0`) for production. `ref=main` is shown below for convenience.

```hcl
module "ent_deployer" {
  source = "git::https://github.com/ent-security/gcp-ent-deploy-role//terraform?ref=main"

  project_id              = "my-gcp-project"
  ent_home_aws_account_id = "051759900972"                              # provided by Ent
  ent_home_aws_role_names = [                                           # provided by Ent
    "HomeProdAssumeAdmin",                                              # human-admin
    "prod-uswest2-eks-pi-1-abcd1234",                                   # EKS Pod Identity (example)
  ]
}

output "ent_deployer_sa_email" {
  value = module.ent_deployer.deployer_sa_email
}

output "ent_wif_provider_resource_name" {
  value = module.ent_deployer.wif_provider_resource_name
}
```

After `terraform apply`, paste the two output values into Ent's GCP connection panel.

### Running locally

```bash
cd terraform/
tofu init
tofu plan -var="project_id=my-gcp-project" \
          -var="ent_home_aws_account_id=051759900972" \
          -var='ent_home_aws_role_names=["HomeProdAssumeAdmin","prod-uswest2-eks-pi-1-abcd1234"]'
tofu apply -var="project_id=my-gcp-project" \
           -var="ent_home_aws_account_id=051759900972" \
           -var='ent_home_aws_role_names=["HomeProdAssumeAdmin","prod-uswest2-eks-pi-1-abcd1234"]'
```

### Terraform inputs

| Variable | Description | Default | Required |
|---|---|---|---|
| `project_id` | GCP project to bootstrap | — | yes |
| `ent_home_aws_account_id` | 12-digit AWS account ID for Ent Home (provided by Ent) | `"000000000000"` (placeholder) | no |
| `ent_home_aws_role_names` | Set of AWS IAM role names federated to the deployer SA (provided by Ent; include every role Ent Home may assume) | — | yes |
| `deployer_sa_id` | Account ID of the deployer SA | `"ent-home-deployer"` | no |
| `wif_pool_id` | Workload Identity Pool ID | `"ent-home-pool"` | no |
| `wif_provider_id` | Pool provider ID for AWS | `"aws-provider"` | no |
| `custom_role_scoped_id` | Role ID for scoped role | `"entHomeDeployerScoped"` | no |
| `custom_role_unscoped_id` | Role ID for unscoped role | `"entHomeDeployerUnscoped"` | no |
| `tenant_name_prefix_glob` | Resource-name prefix used by IAM Conditions (matches ent-platform GCP `local.name_prefix`) | `"g"` | no |
| `enable_apis` | Enable the required Google APIs | `true` | no |
| `labels` | Labels applied to resources that support them | `{}` | no |

### Terraform outputs

| Output | Description |
|---|---|
| `deployer_sa_email` | Email of the deployer service account (paste into Ent) |
| `wif_provider_resource_name` | Full resource name of the WIF provider (paste into Ent) |
| `wif_pool_resource_name` | Full resource name of the WIF pool |
| `project_id` | Project ID that was bootstrapped |
| `custom_role_scoped_name` | Full name of the scoped custom role |
| `custom_role_unscoped_name` | Full name of the unscoped custom role |

## gcloud usage

If you don't use Terraform, `gcloud/bootstrap.sh` runs the equivalent sequence imperatively.

```bash
cd gcloud/
PROJECT_ID=my-gcp-project \
ENT_HOME_AWS_ACCOUNT_ID=051759900972 \
ENT_HOME_AWS_ROLE_NAMES="HomeProdAssumeAdmin prod-uswest2-eks-pi-1-abcd1234" \
./bootstrap.sh
```

`ENT_HOME_AWS_ROLE_NAMES` is a whitespace-separated list.

The script is idempotent — re-running updates existing resources rather than failing. It prints every `gcloud` command and finishes by emitting the same two output values the Terraform module produces.

The role definitions live in `gcloud/custom-role-unscoped.yaml` and `gcloud/custom-role-scoped.yaml`, consumed directly by `gcloud iam roles create`. Edit these files to see or audit the exact permission list.

### gcloud script environment variables

| Variable | Default | Required |
|---|---|---|
| `PROJECT_ID` | — | yes |
| `ENT_HOME_AWS_ACCOUNT_ID` | — | yes |
| `ENT_HOME_AWS_ROLE_NAMES` | — | yes (whitespace-separated list) |
| `DEPLOYER_SA_ID` | `ent-home-deployer` | no |
| `WIF_POOL_ID` | `ent-home-pool` | no |
| `WIF_PROVIDER_ID` | `aws-provider` | no |
| `ROLE_UNSCOPED_ID` | `entHomeDeployerUnscoped` | no |
| `ROLE_SCOPED_ID` | `entHomeDeployerScoped` | no |
| `TENANT_PREFIX` | `g` | no |
| `ENABLE_APIS` | `true` | no |

## Connecting Ent to your project

1. Run one of the deployment paths above.
2. In Ent's web UI, open the GCP connection panel.
3. Paste `deployer_sa_email` into the "Deployer Service Account" field.
4. Paste `wif_provider_resource_name` into the "Workload Identity Provider" field.
5. Click **Save & Test Connection**.

Ent Home will use the federated credentials to deploy tenant infrastructure into your project. Permissions are limited to the two custom roles this module creates.

## Directory structure

```
gcp-ent-deploy-role/
├── README.md
├── .gitignore
├── terraform/
│   ├── main.tf
│   ├── apis.tf
│   ├── custom-role.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── gcloud/
│   ├── bootstrap.sh
│   ├── custom-role-unscoped.yaml
│   └── custom-role-scoped.yaml
└── docs/
    └── permissions.md
```

## Permissions

See [`docs/permissions.md`](docs/permissions.md) for the full verb-by-verb permission list with per-permission rationale.

Summary:

| Service | Scoped by IAM Condition? | Notes |
|---|---|---|
| Cloud Storage | Yes (bucket-name prefix) | `create` / `list` granted at project scope — GCP conditions can't scope bucket create. |
| Secret Manager | Yes (secret-name prefix) | `create` / `list` at project scope, same limitation. |
| Pub/Sub topics | Yes (topic-name prefix) | `create` / `list` at project scope. |
| Pub/Sub subscriptions | Yes (subscription-name prefix) | `create` / `list` at project scope. |
| Artifact Registry | Yes (repo-name prefix) | `create` / `list` at project scope. |
| IAM Service Accounts | No (unconditional, project-scoped) | GCP's IAM Conditions use service accounts' numeric unique IDs in `resource.name`, so an email-prefix condition can never match. The tenant project boundary is the scope. |
| Cloud DNS managed zones | Yes (zone-name prefix) | `create` / `list` at project scope. |
| Compute (VPC, subnets, disks, addresses) | No | Enumerated verbs only (`compute.networks.*`, `compute.subnetworks.*`, etc.); not the full `roles/compute.admin`. |
| GKE | No | `container.clusters.*`, `container.operations.*` only. |
| Cloud SQL | No | Enumerated verbs, not `roles/cloudsql.admin`. |
| Memorystore Redis | No | `redis.instances.*`, `redis.operations.*`. |
| Certificate Manager | No | Enumerated verbs. |
| Vertex AI | No | Prediction/model read only. |
| Service Networking | No | Peering + read only. |

## Resource scoping

GCP tenant resources provisioned by ent-platform are named with an auto-generated prefix: the literal `g`, 15 lowercase hex characters, and a hyphen — for example `g1a2b3c4d5e6f78-`. The prefix is a SHA-256 of the tenant, environment, and region, produced at deploy time by Ent's Home service.

IAM Conditions in this module use the prefix `g` (the variable `tenant_name_prefix_glob`) to match all Ent GCP resources. Note that ent-platform's AWS modules use the literal `e` as their first character; the GCP value is intentionally different and is tracked separately.

**Cross-repo dependency**: this glob assumes the GCP prefix generator in ent-platform's `deploy/tofu/gcp/platform/locals.tf`. If that formula changes shape in a future Ent release, re-apply this module with `tenant_name_prefix_glob` set to the new prefix.

## Services not granted

For transparency, the following are intentionally excluded:

- BigQuery, Dataflow, Cloud Composer
- `serviceusage.*` mutations beyond what this module's API enablement needs (deployer cannot enable or disable APIs)
- `resourcemanager.projects.*` mutations (deployer cannot create, delete, or move projects)
- `billing.*` (billing management)
- `orgpolicy.*`, `accesscontextmanager.*` (organization policies)
- Cloud KMS (not currently used by ent-platform's GCP modules)
- Cloud Build, Cloud Functions, Cloud Run, App Engine

If a future Ent feature requires one of these, a new version of this module will add a scoped statement and the customer will re-apply.

## Versioning

Tagged releases (`v1.0.0`, `v1.1.0`, …). Pin `ref=<tag>` in the module source for production. The changelog in each release lists added, removed, or renamed permissions so you can audit the diff before upgrading.
