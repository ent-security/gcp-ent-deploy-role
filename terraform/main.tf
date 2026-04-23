# Workload Identity Pool for Ent Home AWS authentication.
#
# Authentication flow:
# 1. Ent Home on AWS EKS has an IAM role via Pod Identity.
# 2. The Google Auth Library signs an AWS STS GetCallerIdentity request.
# 3. GCP STS validates the signature with AWS.
# 4. GCP returns a federated token that can impersonate the deployer SA.
# 5. The deployer SA has the permissions defined in custom-role.tf.

resource "google_iam_workload_identity_pool" "ent_home" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "Ent Home AWS Pool"
  description               = "Allows Ent Home on AWS to deploy tenant infrastructure into this GCP project."
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.ent_home.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "AWS Provider"
  description                        = "AWS identity provider for Ent Home authentication."

  aws {
    account_id = var.ent_home_aws_account_id
  }

  # Attribute mapping extracts information from the AWS STS assertion.
  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_role"    = "assertion.arn.extract('assumed-role/{role}/')"
    "attribute.aws_account" = "assertion.account"
  }

  # Only accept credentials from Ent's AWS account.
  attribute_condition = "attribute.aws_account == '${var.ent_home_aws_account_id}'"
}

# Service account that Ent Home impersonates for deployments.

resource "google_service_account" "ent_home_deployer" {
  project      = var.project_id
  account_id   = var.deployer_sa_id
  display_name = "Ent Home Deployer"
  description  = "Service account Ent Home impersonates to deploy tenant infrastructure."
}

# Allow the federated AWS role to impersonate the deployer SA.

resource "google_service_account_iam_member" "ent_home_workload_identity" {
  service_account_id = google_service_account.ent_home_deployer.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.ent_home.name}/attribute.aws_role/${var.ent_home_aws_role_name}"
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
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"
}

resource "google_project_iam_member" "deployer_scoped_storage" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed GCS buckets"
    description = "Limits storage.* verbs to buckets whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"storage.googleapis.com/Bucket\" && resource.name.startsWith(\"projects/_/buckets/${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_secrets" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed Secret Manager secrets"
    description = "Limits secretmanager.* verbs to secrets whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"secretmanager.googleapis.com/Secret\" && resource.name.extract(\"/secrets/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_pubsub_topics" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed Pub/Sub topics"
    description = "Limits pubsub topic verbs to topics whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"pubsub.googleapis.com/Topic\" && resource.name.extract(\"/topics/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_pubsub_subscriptions" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed Pub/Sub subscriptions"
    description = "Limits pubsub subscription verbs to subscriptions whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"pubsub.googleapis.com/Subscription\" && resource.name.extract(\"/subscriptions/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_artifacts" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed Artifact Registry repositories"
    description = "Limits artifactregistry verbs to repositories whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"artifactregistry.googleapis.com/Repository\" && resource.name.extract(\"/repositories/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_service_accounts" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed service accounts"
    description = "Limits iam.serviceAccounts verbs to SAs whose account ID starts with the Ent tenant prefix."
    expression  = "resource.type == \"iam.googleapis.com/ServiceAccount\" && resource.name.extract(\"/serviceAccounts/{email}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}

resource "google_project_iam_member" "deployer_scoped_dns" {
  project = var.project_id
  role    = google_project_iam_custom_role.scoped.name
  member  = "serviceAccount:${google_service_account.ent_home_deployer.email}"

  condition {
    title       = "Scoped to Ent-prefixed DNS managed zones"
    description = "Limits dns verbs to managed zones whose name starts with the Ent tenant prefix."
    expression  = "resource.type == \"dns.googleapis.com/ManagedZone\" && resource.name.extract(\"/managedZones/{name}\").startsWith(\"${var.tenant_name_prefix_glob}\")"
  }
}
