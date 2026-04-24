# Two custom roles split by scoping strategy.
#
# entHomeDeployerUnscoped - permissions for GCP services whose IAM does not
# support resource.name conditions (Compute, GKE, Cloud SQL, Redis,
# Certificate Manager, Vertex AI, Service Networking). Bound unconditionally
# via a single project-level IAM member.
#
# entHomeDeployerScoped - permissions for services that DO support resource
# conditions (Storage, Secret Manager, Pub/Sub, Artifact Registry, IAM
# service accounts, DNS). Bound once per service family with a
# resource-type-and-prefix condition so the deployer can only touch
# Ent-prefixed resources.
#
# Create operations that evaluate the condition against the parent project
# (storage.buckets.create, pubsub.topics.create, etc.) cannot be resource-
# scoped by IAM Conditions and are granted via the unscoped role. This is a
# GCP IAM limitation, not a design choice.

# --- Unscoped role: services that cannot use resource conditions ---

resource "google_project_iam_custom_role" "unscoped" {
  project     = var.project_id
  role_id     = var.custom_role_unscoped_id
  title       = "Ent Home Deployer (Unscoped)"
  description = "Permissions for Ent Home to manage GCP services whose IAM does not support resource-name conditions. Granted unconditionally at the project level."
  stage       = "GA"

  permissions = [
    # --- Compute: networks, subnets, firewalls, disks, addresses ---
    "compute.addresses.create",
    "compute.addresses.delete",
    "compute.addresses.get",
    "compute.addresses.list",
    "compute.addresses.use",
    "compute.addresses.useInternal",
    "compute.diskTypes.get",
    "compute.diskTypes.list",
    "compute.disks.create",
    "compute.disks.delete",
    "compute.disks.get",
    "compute.disks.getIamPolicy",
    "compute.disks.list",
    "compute.disks.setIamPolicy",
    "compute.disks.setLabels",
    "compute.disks.update",
    "compute.disks.use",
    "compute.disks.useReadOnly",
    "compute.firewalls.create",
    "compute.firewalls.delete",
    "compute.firewalls.get",
    "compute.firewalls.list",
    "compute.firewalls.update",
    "compute.forwardingRules.create",
    "compute.forwardingRules.delete",
    "compute.forwardingRules.get",
    "compute.forwardingRules.list",
    "compute.forwardingRules.setLabels",
    "compute.forwardingRules.update",
    "compute.globalAddresses.create",
    "compute.globalAddresses.createInternal",
    "compute.globalAddresses.delete",
    "compute.globalAddresses.get",
    "compute.globalAddresses.list",
    "compute.globalAddresses.use",
    "compute.globalForwardingRules.create",
    "compute.globalForwardingRules.delete",
    "compute.globalForwardingRules.get",
    "compute.globalForwardingRules.list",
    "compute.globalForwardingRules.setLabels",
    "compute.globalForwardingRules.update",
    "compute.globalOperations.get",
    "compute.globalOperations.list",
    "compute.instanceGroupManagers.get",
    "compute.instanceGroupManagers.list",
    "compute.machineTypes.get",
    "compute.machineTypes.list",
    "compute.networks.addPeering",
    "compute.networks.create",
    "compute.networks.delete",
    "compute.networks.get",
    "compute.networks.list",
    "compute.networks.removePeering",
    "compute.networks.update",
    "compute.networks.updatePeering",
    "compute.networks.updatePolicy",
    "compute.networks.use",
    "compute.networks.useExternalIp",
    "compute.projects.get",
    "compute.regionOperations.get",
    "compute.regionOperations.list",
    "compute.regions.get",
    "compute.regions.list",
    "compute.routers.create",
    "compute.routers.delete",
    "compute.routers.get",
    "compute.routers.list",
    "compute.routers.update",
    "compute.routers.use",
    "compute.routes.create",
    "compute.routes.delete",
    "compute.routes.get",
    "compute.routes.list",
    "compute.subnetworks.create",
    "compute.subnetworks.delete",
    "compute.subnetworks.expandIpCidrRange",
    "compute.subnetworks.get",
    "compute.subnetworks.getIamPolicy",
    "compute.subnetworks.list",
    "compute.subnetworks.setIamPolicy",
    "compute.subnetworks.update",
    "compute.subnetworks.use",
    "compute.subnetworks.useExternalIp",
    "compute.zoneOperations.get",
    "compute.zoneOperations.list",
    "compute.zones.get",
    "compute.zones.list",

    # --- GKE (Kubernetes Engine) ---
    "container.clusters.create",
    "container.clusters.delete",
    "container.clusters.get",
    "container.clusters.getCredentials",
    "container.clusters.list",
    "container.clusters.update",
    "container.operations.get",
    "container.operations.list",

    # --- Cloud SQL ---
    "cloudsql.backupRuns.create",
    "cloudsql.backupRuns.delete",
    "cloudsql.backupRuns.get",
    "cloudsql.backupRuns.list",
    "cloudsql.databases.create",
    "cloudsql.databases.delete",
    "cloudsql.databases.get",
    "cloudsql.databases.list",
    "cloudsql.databases.update",
    "cloudsql.instances.create",
    "cloudsql.instances.delete",
    "cloudsql.instances.failover",
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "cloudsql.instances.restart",
    "cloudsql.instances.update",
    "cloudsql.sslCerts.create",
    "cloudsql.sslCerts.delete",
    "cloudsql.sslCerts.get",
    "cloudsql.sslCerts.list",
    "cloudsql.users.create",
    "cloudsql.users.delete",
    "cloudsql.users.list",
    "cloudsql.users.update",

    # --- Memorystore Redis ---
    "redis.instances.create",
    "redis.instances.delete",
    "redis.instances.get",
    "redis.instances.list",
    "redis.instances.update",
    "redis.operations.get",
    "redis.operations.list",

    # --- Certificate Manager ---
    "certificatemanager.certmapentries.create",
    "certificatemanager.certmapentries.delete",
    "certificatemanager.certmapentries.get",
    "certificatemanager.certmapentries.list",
    "certificatemanager.certmapentries.update",
    "certificatemanager.certmaps.create",
    "certificatemanager.certmaps.delete",
    "certificatemanager.certmaps.get",
    "certificatemanager.certmaps.list",
    "certificatemanager.certmaps.update",
    "certificatemanager.certs.create",
    "certificatemanager.certs.delete",
    "certificatemanager.certs.get",
    "certificatemanager.certs.list",
    "certificatemanager.certs.update",
    "certificatemanager.dnsauthorizations.create",
    "certificatemanager.dnsauthorizations.delete",
    "certificatemanager.dnsauthorizations.get",
    "certificatemanager.dnsauthorizations.list",
    "certificatemanager.dnsauthorizations.update",
    "certificatemanager.locations.get",
    "certificatemanager.locations.list",
    "certificatemanager.operations.cancel",
    "certificatemanager.operations.delete",
    "certificatemanager.operations.get",
    "certificatemanager.operations.list",

    # --- Vertex AI ---
    "aiplatform.endpoints.predict",
    "aiplatform.endpoints.list",
    "aiplatform.endpoints.get",
    "aiplatform.models.list",
    "aiplatform.models.get",

    # --- Service Networking (VPC peering for Cloud SQL private IP) ---
    "servicenetworking.services.addPeering",
    "servicenetworking.services.deleteConnection",
    "servicenetworking.services.get",
    "servicenetworking.services.use",

    # --- Create verbs for services whose conditions cannot scope create ops ---
    # storage.buckets.create, pubsub.topics.create, etc. evaluate conditions
    # against the project, not the future resource name, so cannot be scoped.
    "storage.buckets.create",
    "storage.buckets.list",
    "secretmanager.secrets.create",
    "secretmanager.secrets.list",
    "pubsub.topics.create",
    "pubsub.topics.list",
    "pubsub.subscriptions.create",
    "pubsub.subscriptions.list",
    "artifactregistry.repositories.create",
    "artifactregistry.repositories.list",
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.list",
    "dns.managedZones.create",
    "dns.managedZones.list",

    # --- Custom role management (so the deployer can introspect this role) ---
    "iam.roles.get",
    "iam.roles.list",

    # --- Resource Manager (reading project-level IAM) ---
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",

    # --- Service Usage (reading which Google APIs are enabled) ---
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]
}

# --- Scoped role: services that DO support resource conditions ---

resource "google_project_iam_custom_role" "scoped" {
  project     = var.project_id
  role_id     = var.custom_role_scoped_id
  title       = "Ent Home Deployer (Scoped)"
  description = "Permissions for Ent Home to manage Ent-prefixed resources in services that support IAM resource-name conditions. Bound conditionally, one binding per service."
  stage       = "GA"

  permissions = [
    # --- Cloud Storage (per-bucket and per-object) ---
    "storage.buckets.delete",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
    "storage.buckets.update",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.getIamPolicy",
    "storage.objects.list",
    "storage.objects.setIamPolicy",
    "storage.objects.update",

    # --- Secret Manager (per-secret) ---
    "secretmanager.secrets.delete",
    "secretmanager.secrets.get",
    "secretmanager.secrets.getIamPolicy",
    "secretmanager.secrets.setIamPolicy",
    "secretmanager.secrets.update",
    "secretmanager.versions.access",
    "secretmanager.versions.add",
    "secretmanager.versions.destroy",
    "secretmanager.versions.disable",
    "secretmanager.versions.enable",
    "secretmanager.versions.get",
    "secretmanager.versions.list",

    # --- Pub/Sub topics + subscriptions (per-topic, per-subscription) ---
    "pubsub.subscriptions.consume",
    "pubsub.subscriptions.delete",
    "pubsub.subscriptions.get",
    "pubsub.subscriptions.getIamPolicy",
    "pubsub.subscriptions.setIamPolicy",
    "pubsub.subscriptions.update",
    "pubsub.topics.attachSubscription",
    "pubsub.topics.delete",
    "pubsub.topics.detachSubscription",
    "pubsub.topics.get",
    "pubsub.topics.getIamPolicy",
    "pubsub.topics.publish",
    "pubsub.topics.setIamPolicy",
    "pubsub.topics.update",

    # --- Artifact Registry (per-repository) ---
    "artifactregistry.repositories.delete",
    "artifactregistry.repositories.deleteArtifacts",
    "artifactregistry.repositories.downloadArtifacts",
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.getIamPolicy",
    "artifactregistry.repositories.setIamPolicy",
    "artifactregistry.repositories.update",
    "artifactregistry.repositories.uploadArtifacts",

    # --- IAM Service Accounts (per-SA) ---
    "iam.serviceAccounts.actAs",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
    "iam.serviceAccounts.update",

    # --- Cloud DNS (per-zone) ---
    "dns.changes.create",
    "dns.changes.get",
    "dns.changes.list",
    "dns.managedZones.delete",
    "dns.managedZones.get",
    "dns.managedZones.getIamPolicy",
    "dns.managedZones.setIamPolicy",
    "dns.managedZones.update",
    "dns.resourceRecordSets.create",
    "dns.resourceRecordSets.delete",
    "dns.resourceRecordSets.get",
    "dns.resourceRecordSets.list",
    "dns.resourceRecordSets.update",
  ]
}
