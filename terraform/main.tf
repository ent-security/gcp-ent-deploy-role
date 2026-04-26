# Workload Identity Pool for Ent Home AWS authentication.
#
# Authentication flow:
# 1. Ent Home on AWS EKS has an IAM role via Pod Identity.
# 2. The Google Auth Library signs an AWS STS GetCallerIdentity request.
# 3. GCP STS validates the signature with AWS.
# 4. GCP returns a federated token that can impersonate the deployer SA.
# 5. The deployer SA has the permissions defined in custom-role.tf.
#
# When `existing_deployer_sa_email` is set, the SA + WIF pool are assumed to
# live elsewhere (typically a central platform project shared across tenants),
# and this module only creates the custom roles and grants them to that SA.

locals {
  use_existing_sa    = var.existing_deployer_sa_email != ""
  deployer_sa_email  = local.use_existing_sa ? var.existing_deployer_sa_email : one(google_service_account.ent_home_deployer[*].email)
  deployer_sa_member = "serviceAccount:${local.deployer_sa_email}"
}

resource "google_iam_workload_identity_pool" "ent_home" {
  count = local.use_existing_sa ? 0 : 1

  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "Ent Home AWS Pool"
  description               = "Allows Ent Home on AWS to deploy tenant infrastructure into this GCP project."
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  count = local.use_existing_sa ? 0 : 1

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.ent_home[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "AWS Provider"
  description                        = "AWS identity provider for Ent Home authentication."

  aws {
    account_id = var.ent_home_aws_account_id
  }

  # Attribute mapping extracts information from the AWS STS assertion.
  # google.subject is mapped to the extracted role name rather than the full ARN:
  # GCP caps google.subject at 127 bytes, and an ARN like
  # "arn:aws:sts::<12>:assumed-role/<role>/<session>" easily exceeds that when
  # EKS Pod Identity generates long session names.
  attribute_mapping = {
    "google.subject"        = "assertion.arn.extract('assumed-role/{role}/')"
    "attribute.aws_role"    = "assertion.arn.extract('assumed-role/{role}/')"
    "attribute.aws_account" = "assertion.account"
  }

  # Only accept credentials from Ent's AWS account.
  attribute_condition = "attribute.aws_account == '${var.ent_home_aws_account_id}'"

  # ent_home_aws_role_names is required in default mode (its length validation
  # moved here from the variable so external-SA mode can default to []).
  lifecycle {
    precondition {
      condition     = length(var.ent_home_aws_role_names) > 0
      error_message = "ent_home_aws_role_names must contain at least one role name when not using existing_deployer_sa_email."
    }
  }
}

# Service account that Ent Home impersonates for deployments.

resource "google_service_account" "ent_home_deployer" {
  count = local.use_existing_sa ? 0 : 1

  project      = var.project_id
  account_id   = var.deployer_sa_id
  display_name = "Ent Home Deployer"
  description  = "Service account Ent Home impersonates to deploy tenant infrastructure."
}

# Allow each federated AWS role to impersonate the deployer SA. Callers must
# include both the EKS Pod Identity role the ent-home-api pod runs under at
# runtime (used by deployments) and any human-admin role (used for manual
# bootstrap or troubleshooting). Bindings are scoped by the extracted role
# name (attribute.aws_role), not by the full ARN.

resource "google_service_account_iam_member" "ent_home_workload_identity" {
  for_each = local.use_existing_sa ? toset([]) : var.ent_home_aws_role_names

  service_account_id = google_service_account.ent_home_deployer[0].name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.ent_home[0].name}/attribute.aws_role/${each.value}"
}

# --- Role bindings ---
#
# The deployer SA receives the unscoped custom role unconditionally, and the
# scoped custom role in multiple bindings with per-service resource conditions.
# Conditions gate the entire binding: for a binding whose condition filters
# on storage buckets, a pubsub verb from the same role is unreachable because
# the condition evaluates false for non-storage resources.

resource "google_project_iam_member" "deployer_unscoped" {
  project = var.project_id
  role    = google_project_iam_custom_role.unscoped.name
  member  = local.deployer_sa_member
}

# GKE in-cluster access: the custom role covers container.clusters.* for the
# cluster resource itself. The in-cluster Kubernetes API (namespaces, secrets,
# configmaps, cluster-scoped RBAC, CRDs, webhook configurations, priority
# classes, leases, etc.) is guarded by the container.<k8s> permission family.
# roles/container.developer is insufficient: it excludes cluster-scoped RBAC,
# which Helm charts routinely install (cert-manager, external-dns, operators).
# The only predefined role that includes cluster-scoped RBAC is
# roles/container.admin, which is what ent-platform's original GCP tofu
# granted. The tenant project boundary remains the blast radius.
resource "google_project_iam_member" "deployer_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = local.deployer_sa_member
}

resource "google_project_iam_member" "deployer_scoped_storage" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed GCS buckets"
    description = "Limits storage.* verbs to buckets whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"storage.googleapis.com/Bucket\" && resource.name.startsWith(\"projects/_/buckets/${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_secrets" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed Secret Manager secrets"
    description = "Limits secretmanager.* verbs to secrets whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"secretmanager.googleapis.com/Secret\" && resource.name.extract(\"/secrets/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_pubsub_topics" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed Pub/Sub topics"
    description = "Limits pubsub topic verbs to topics whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"pubsub.googleapis.com/Topic\" && resource.name.extract(\"/topics/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_pubsub_subscriptions" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed Pub/Sub subscriptions"
    description = "Limits pubsub subscription verbs to subscriptions whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"pubsub.googleapis.com/Subscription\" && resource.name.extract(\"/subscriptions/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_artifacts" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed Artifact Registry repositories"
    description = "Limits artifactregistry verbs to repositories whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"artifactregistry.googleapis.com/Repository\" && resource.name.extract(\"/repositories/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

# IAM service-account verbs must be granted unconditionally within the project:
# GCP's IAM condition engine substitutes the service account's numeric unique ID
# (e.g. "projects/-/serviceAccounts/108685713668969420602") into resource.name, not
# the email. A name-prefix condition like startsWith("${var.tenant_name_prefix_glob}")
# can never match a numeric ID. The tenant project itself is the blast-radius
# boundary for these verbs.
resource "google_project_iam_member" "deployer_scoped_service_accounts" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member
}

resource "google_project_iam_member" "deployer_scoped_dns" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = local.deployer_sa_member

  condition {
    title       = "Scoped to Ent-prefixed DNS managed zones"
    description = "Limits dns verbs to managed zones whose name starts with the Ent tenant prefix. GCP's IAM condition engine lowercases the DNS resource path to /managedzones/, so that casing must be used here."
    expression  = "resource.type == \"dns.googleapis.com/ManagedZone\" && resource.name.extract(\"/managedzones/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}
