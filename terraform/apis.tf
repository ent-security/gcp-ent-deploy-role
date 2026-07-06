# Google APIs required by Ent Home for tenant deployments.
#
# Bundling API enablement here keeps serviceusage.serviceUsageAdmin out of the
# deployer role. Trade-off: adding a required API in a future ent-platform
# release means the customer must re-apply this module. That is a better
# failure mode (clear error, clear fix) than silently granting broad
# API-enablement rights to the deployer.

locals {
  required_apis = [
    "aiplatform.googleapis.com",           # Vertex AI for embeddings and model inference
    "apikeys.googleapis.com",              # API Keys API (create/manage API keys)
    "artifactregistry.googleapis.com",     # Container image repositories
    "certificatemanager.googleapis.com",   # Managed SSL certificates
    "cloudbilling.googleapis.com",         # Cloud Billing API (project billing info)
    "cloudresourcemanager.googleapis.com", # Project-level IAM bindings
    "compute.googleapis.com",              # VPC, subnets, firewall, disks, addresses
    "container.googleapis.com",            # GKE cluster + node pool management
    "dns.googleapis.com",                  # Cloud DNS managed zones
    "file.googleapis.com",                 # Filestore shared model cache (GLiNER ONNX, Dynamo/TEI)
    "iam.googleapis.com",                  # Service account + custom role management
    "iamcredentials.googleapis.com",       # Service account impersonation
    "logging.googleapis.com",              # Cloud Logging (used by GKE)
    "monitoring.googleapis.com",           # Cloud Monitoring (used by GKE)
    "networksecurity.googleapis.com",      # ServerTlsPolicy for ingest front-end mTLS
    "pubsub.googleapis.com",               # Pub/Sub topics + subscriptions
    "redis.googleapis.com",                # Memorystore Redis
    "secretmanager.googleapis.com",        # Secrets
    "servicedirectory.googleapis.com",     # PSC global forwarding rules create a Service Directory namespace
    "servicenetworking.googleapis.com",    # VPC peering for Cloud SQL private IP
    "serviceusage.googleapis.com",         # Needed by tenant tofu to inspect which APIs are enabled
    "sqladmin.googleapis.com",             # Cloud SQL
    "storage.googleapis.com",              # GCS buckets
  ]
}

resource "google_project_service" "required" {
  for_each = var.enable_apis ? toset(local.required_apis) : toset([])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
