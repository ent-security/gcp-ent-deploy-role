#!/usr/bin/env bash
#
# gcloud-based bootstrap for the Ent Home deployer service account.
# Equivalent to terraform/ apply. Idempotent: safe to re-run.
#
# Usage:
#   PROJECT_ID=my-gcp-project \
#   ENT_HOME_AWS_ACCOUNT_ID=051759900972 \
#   ENT_HOME_AWS_ROLE_NAME=HomeProdAssumeAdmin \
#   ./bootstrap.sh
#
# Optional overrides:
#   DEPLOYER_SA_ID         (default: ent-home-deployer)
#   WIF_POOL_ID            (default: ent-home-pool)
#   WIF_PROVIDER_ID        (default: aws-provider)
#   ROLE_UNSCOPED_ID       (default: entHomeDeployerUnscoped)
#   ROLE_SCOPED_ID         (default: entHomeDeployerScoped)
#   TENANT_PREFIX          (default: e)
#   ENABLE_APIS            (default: true; set to false to skip API enablement)

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${ENT_HOME_AWS_ACCOUNT_ID:?ENT_HOME_AWS_ACCOUNT_ID is required}"
: "${ENT_HOME_AWS_ROLE_NAME:?ENT_HOME_AWS_ROLE_NAME is required}"

DEPLOYER_SA_ID="${DEPLOYER_SA_ID:-ent-home-deployer}"
WIF_POOL_ID="${WIF_POOL_ID:-ent-home-pool}"
WIF_PROVIDER_ID="${WIF_PROVIDER_ID:-aws-provider}"
ROLE_UNSCOPED_ID="${ROLE_UNSCOPED_ID:-entHomeDeployerUnscoped}"
ROLE_SCOPED_ID="${ROLE_SCOPED_ID:-entHomeDeployerScoped}"
TENANT_PREFIX="${TENANT_PREFIX:-e}"
ENABLE_APIS="${ENABLE_APIS:-true}"

if ! [[ "$ENT_HOME_AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "ENT_HOME_AWS_ACCOUNT_ID must be a 12-digit AWS account ID." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
role_unscoped_file="$script_dir/custom-role-unscoped.yaml"
role_scoped_file="$script_dir/custom-role-scoped.yaml"

for f in "$role_unscoped_file" "$role_scoped_file"; do
  [[ -f "$f" ]] || { echo "Missing role file: $f" >&2; exit 1; }
done

required_apis=(
  aiplatform.googleapis.com
  artifactregistry.googleapis.com
  certificatemanager.googleapis.com
  cloudresourcemanager.googleapis.com
  compute.googleapis.com
  container.googleapis.com
  dns.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  logging.googleapis.com
  monitoring.googleapis.com
  pubsub.googleapis.com
  redis.googleapis.com
  secretmanager.googleapis.com
  servicenetworking.googleapis.com
  sqladmin.googleapis.com
  storage.googleapis.com
)

log() { printf '\n=== %s ===\n' "$*"; }

if [[ "$ENABLE_APIS" == "true" ]]; then
  log "Enabling required APIs"
  gcloud services enable "${required_apis[@]}" --project="$PROJECT_ID"
else
  log "Skipping API enablement (ENABLE_APIS=$ENABLE_APIS)"
fi

log "Creating Workload Identity Pool: $WIF_POOL_ID"
if gcloud iam workload-identity-pools describe "$WIF_POOL_ID" \
    --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
  echo "Pool already exists, skipping."
else
  gcloud iam workload-identity-pools create "$WIF_POOL_ID" \
    --project="$PROJECT_ID" \
    --location=global \
    --display-name="Ent Home AWS Pool" \
    --description="Allows Ent Home on AWS to deploy tenant infrastructure into this GCP project."
fi

log "Creating AWS provider in the pool: $WIF_PROVIDER_ID"
if gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER_ID" \
    --project="$PROJECT_ID" --location=global \
    --workload-identity-pool="$WIF_POOL_ID" >/dev/null 2>&1; then
  echo "Provider already exists, skipping."
else
  gcloud iam workload-identity-pools providers create-aws "$WIF_PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location=global \
    --workload-identity-pool="$WIF_POOL_ID" \
    --account-id="$ENT_HOME_AWS_ACCOUNT_ID" \
    --attribute-mapping="google.subject=assertion.arn,attribute.aws_role=assertion.arn.extract('assumed-role/{role}/'),attribute.aws_account=assertion.account" \
    --attribute-condition="attribute.aws_account == '$ENT_HOME_AWS_ACCOUNT_ID'"
fi

log "Creating deployer service account: $DEPLOYER_SA_ID"
deployer_email="${DEPLOYER_SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$deployer_email" \
    --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Service account already exists, skipping."
else
  gcloud iam service-accounts create "$DEPLOYER_SA_ID" \
    --project="$PROJECT_ID" \
    --display-name="Ent Home Deployer" \
    --description="Service account Ent Home impersonates to deploy tenant infrastructure."
fi

project_number="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
pool_resource="projects/${project_number}/locations/global/workloadIdentityPools/${WIF_POOL_ID}"
provider_resource="${pool_resource}/providers/${WIF_PROVIDER_ID}"
wif_principal="principalSet://iam.googleapis.com/${pool_resource}/attribute.aws_role/${ENT_HOME_AWS_ROLE_NAME}"

log "Granting WIF principal workloadIdentityUser on deployer SA"
gcloud iam service-accounts add-iam-policy-binding "$deployer_email" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="$wif_principal" >/dev/null

create_or_update_role() {
  local role_id="$1" role_file="$2"
  if gcloud iam roles describe "$role_id" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Updating custom role: $role_id"
    gcloud iam roles update "$role_id" --project="$PROJECT_ID" --file="$role_file"
  else
    log "Creating custom role: $role_id"
    gcloud iam roles create "$role_id" --project="$PROJECT_ID" --file="$role_file"
  fi
}

create_or_update_role "$ROLE_UNSCOPED_ID" "$role_unscoped_file"
create_or_update_role "$ROLE_SCOPED_ID" "$role_scoped_file"

deployer_member="serviceAccount:${deployer_email}"
unscoped_role_name="projects/${PROJECT_ID}/roles/${ROLE_UNSCOPED_ID}"
scoped_role_name="projects/${PROJECT_ID}/roles/${ROLE_SCOPED_ID}"

log "Binding unscoped role to deployer (unconditional)"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --role="$unscoped_role_name" \
  --member="$deployer_member" \
  --condition=None >/dev/null

bind_scoped() {
  local title="$1" expression="$2"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --role="$scoped_role_name" \
    --member="$deployer_member" \
    --condition="title=${title},expression=${expression}" >/dev/null
}

log "Binding scoped role per service family"
bind_scoped \
  "ent-storage-buckets" \
  "resource.type == 'storage.googleapis.com/Bucket' && resource.name.startsWith('projects/_/buckets/${TENANT_PREFIX}')"
bind_scoped \
  "ent-secrets" \
  "resource.type == 'secretmanager.googleapis.com/Secret' && resource.name.extract('/secrets/{name}').startsWith('${TENANT_PREFIX}')"
bind_scoped \
  "ent-pubsub-topics" \
  "resource.type == 'pubsub.googleapis.com/Topic' && resource.name.extract('/topics/{name}').startsWith('${TENANT_PREFIX}')"
bind_scoped \
  "ent-pubsub-subscriptions" \
  "resource.type == 'pubsub.googleapis.com/Subscription' && resource.name.extract('/subscriptions/{name}').startsWith('${TENANT_PREFIX}')"
bind_scoped \
  "ent-artifact-repos" \
  "resource.type == 'artifactregistry.googleapis.com/Repository' && resource.name.extract('/repositories/{name}').startsWith('${TENANT_PREFIX}')"
bind_scoped \
  "ent-service-accounts" \
  "resource.type == 'iam.googleapis.com/ServiceAccount' && resource.name.extract('/serviceAccounts/{email}').startsWith('${TENANT_PREFIX}')"
bind_scoped \
  "ent-dns-zones" \
  "resource.type == 'dns.googleapis.com/ManagedZone' && resource.name.extract('/managedZones/{name}').startsWith('${TENANT_PREFIX}')"

cat <<OUTPUT

=== Bootstrap complete ===

Paste these values into Ent's GCP connection panel:

  deployer_sa_email          : ${deployer_email}
  wif_provider_resource_name : ${provider_resource}

For reference:
  project_id                 : ${PROJECT_ID}
  wif_pool_resource_name     : ${pool_resource}
  custom_role_unscoped_name  : ${unscoped_role_name}
  custom_role_scoped_name    : ${scoped_role_name}
OUTPUT
