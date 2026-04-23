# Permission catalog

Every permission granted by this module, grouped by service, with a one-line rationale tying it to the Ent Home tofu resource or SDK call that requires it.

The `Scoped?` column notes whether the permission is granted via a conditional binding (limited to Ent-prefixed resources) or unconditionally at project scope.

## Cloud Storage (GCS)

Used by ent-platform's `deploy/tofu/gcp/platform/storage.tf`, `opensearch.tf`, and `platform-monitoring/main.tf` to provision the 13 data buckets, OpenSearch snapshots bucket, and Loki chunks bucket.

| Permission | Scoped? | Used for |
|---|---|---|
| `storage.buckets.create` | No | Creating a new bucket (GCP condition cannot scope project-level create). |
| `storage.buckets.list` | No | `google_storage_bucket` plan refresh; `Storage.list()` from Home's GCS client. |
| `storage.buckets.get` | Yes | Reading bucket metadata during tofu refresh. |
| `storage.buckets.update` | Yes | Modifying versioning, lifecycle, labels on existing buckets. |
| `storage.buckets.delete` | Yes | `terraform destroy`. |
| `storage.buckets.getIamPolicy` | Yes | Reading bucket IAM bindings. |
| `storage.buckets.setIamPolicy` | Yes | Granting `roles/storage.objectUser` to the app SA (from `google_storage_bucket_iam_member`). |
| `storage.objects.create` | Yes | Home's Java-side `Storage.create()` calls during deployment. |
| `storage.objects.get` | Yes | Reading objects from Home's deployment code. |
| `storage.objects.list` | Yes | Listing object keys. |
| `storage.objects.update` | Yes | Updating object metadata. |
| `storage.objects.delete` | Yes | Cleanup / deployment rollback. |
| `storage.objects.getIamPolicy` | Yes | Rare; reading object-level ACLs. |
| `storage.objects.setIamPolicy` | Yes | Rare; setting object-level ACLs. |

## Secret Manager

Used by `secrets.tf` to provision the database master password secret.

| Permission | Scoped? | Used for |
|---|---|---|
| `secretmanager.secrets.create` | No | Creating new secrets (project-level). |
| `secretmanager.secrets.list` | No | Plan refresh. |
| `secretmanager.secrets.get` | Yes | Reading secret metadata. |
| `secretmanager.secrets.update` | Yes | Updating secret labels or rotation config. |
| `secretmanager.secrets.delete` | Yes | Destroy. |
| `secretmanager.secrets.getIamPolicy` | Yes | Reading secret IAM. |
| `secretmanager.secrets.setIamPolicy` | Yes | Granting `roles/secretmanager.secretAccessor` to the app SA. |
| `secretmanager.versions.add` | Yes | `google_secret_manager_secret_version` — writing the password value. |
| `secretmanager.versions.access` | Yes | Reading the current version at apply time for downstream resources. |
| `secretmanager.versions.get` | Yes | Plan refresh. |
| `secretmanager.versions.list` | Yes | Listing versions. |
| `secretmanager.versions.destroy` | Yes | Cleanup. |
| `secretmanager.versions.disable` | Yes | Rotating credentials. |
| `secretmanager.versions.enable` | Yes | Rotating credentials. |

## Pub/Sub

Used by `pubsub.tf` to provision 31 topics, 31 subscriptions, and 31 DLQ topics with per-topic/subscription IAM bindings.

| Permission | Scoped? | Used for |
|---|---|---|
| `pubsub.topics.create` | No | Creating topics (project-level). |
| `pubsub.topics.list` | No | Plan refresh. |
| `pubsub.topics.get` | Yes | Reading topic metadata. |
| `pubsub.topics.update` | Yes | Changing retention, schema. |
| `pubsub.topics.delete` | Yes | Destroy. |
| `pubsub.topics.getIamPolicy` | Yes | Reading topic IAM. |
| `pubsub.topics.setIamPolicy` | Yes | Granting `roles/pubsub.publisher` to the app SA. |
| `pubsub.topics.publish` | Yes | Home deployment validation publishes a probe message. |
| `pubsub.topics.attachSubscription` | Yes | Wiring subscriptions to topics. |
| `pubsub.topics.detachSubscription` | Yes | Destroy. |
| `pubsub.subscriptions.create` | No | Creating subscriptions (project-level). |
| `pubsub.subscriptions.list` | No | Plan refresh. |
| `pubsub.subscriptions.get` | Yes | Reading subscription metadata. |
| `pubsub.subscriptions.update` | Yes | Changing retry policy, ack deadline. |
| `pubsub.subscriptions.delete` | Yes | Destroy. |
| `pubsub.subscriptions.getIamPolicy` | Yes | Reading subscription IAM. |
| `pubsub.subscriptions.setIamPolicy` | Yes | Granting `roles/pubsub.subscriber` to the app SA. |
| `pubsub.subscriptions.consume` | Yes | Home deployment validation consumes a probe message. |

## Artifact Registry

Used by `artifact-registry.tf` to provision 5 Docker repositories (ingest-api, platform-admin-api, event-indexer, ent-db-setup, otel-collector-contrib).

| Permission | Scoped? | Used for |
|---|---|---|
| `artifactregistry.repositories.create` | No | Creating repositories (project-level). |
| `artifactregistry.repositories.list` | No | Plan refresh. |
| `artifactregistry.repositories.get` | Yes | Reading repository metadata. |
| `artifactregistry.repositories.update` | Yes | Changing retention, labels. |
| `artifactregistry.repositories.delete` | Yes | Destroy. |
| `artifactregistry.repositories.getIamPolicy` | Yes | Reading repository IAM. |
| `artifactregistry.repositories.setIamPolicy` | Yes | Granting push access to CI/CD principals. |
| `artifactregistry.repositories.downloadArtifacts` | Yes | Image pull during deployment validation. |
| `artifactregistry.repositories.uploadArtifacts` | Yes | Image push during deployment. |
| `artifactregistry.repositories.deleteArtifacts` | Yes | Cleanup of old images. |

## IAM Service Accounts

Used by `identity.tf` and monitoring modules to create per-pod service accounts (app, opensearch, ingest-api, event-indexer, platform-admin-api, model-builder, external-dns, loki).

| Permission | Scoped? | Used for |
|---|---|---|
| `iam.serviceAccounts.create` | No | Creating per-pod SAs (project-level). |
| `iam.serviceAccounts.list` | No | Plan refresh. |
| `iam.serviceAccounts.get` | Yes | Reading SA metadata. |
| `iam.serviceAccounts.update` | Yes | Changing display name, description. |
| `iam.serviceAccounts.delete` | Yes | Destroy. |
| `iam.serviceAccounts.getIamPolicy` | Yes | Reading SA-level IAM bindings. |
| `iam.serviceAccounts.setIamPolicy` | Yes | Granting `roles/iam.workloadIdentityUser` from Kubernetes SAs to GCP SAs. |
| `iam.serviceAccounts.actAs` | Yes | Allowing the deployer to use app SAs when creating GKE workloads bound via Workload Identity. |

## Cloud DNS

Used by `platform-dns/main.tf` to provision the per-tenant public DNS zone, and by `certificate-manager.tf` for DNS validation records.

| Permission | Scoped? | Used for |
|---|---|---|
| `dns.managedZones.create` | No | Creating zones (project-level). |
| `dns.managedZones.list` | No | Plan refresh. |
| `dns.managedZones.get` | Yes | Reading zone metadata. |
| `dns.managedZones.update` | Yes | Changing DNSSEC, private visibility. |
| `dns.managedZones.delete` | Yes | Destroy. |
| `dns.managedZones.getIamPolicy` | Yes | Reading zone IAM. |
| `dns.managedZones.setIamPolicy` | Yes | Granting `roles/dns.admin` to the external-dns SA on the zone. |
| `dns.resourceRecordSets.{create, get, list, update, delete}` | Yes | Writing DNS records (cert-manager DNS01 validation, etc.). |
| `dns.changes.{create, get, list}` | Yes | Record-set change plumbing. |

## Compute Engine

Used by `networking.tf`, `opensearch.tf`, `databases.tf` — VPC + peering, firewall rules, global addresses, forwarding rules, persistent disks for OpenSearch.

Not conditionally scoped: `compute.*` IAM does not support `resource.name` conditions for the actions Home needs at create time.

| Permission group | Rationale |
|---|---|
| `compute.networks.*` (create, get, list, update, delete, addPeering, removePeering, updatePolicy, use, useExternalIp) | VPC creation + management. |
| `compute.subnetworks.*` (create, get, list, update, delete, expandIpCidrRange, use, useExternalIp, getIamPolicy, setIamPolicy) | Subnet management, used by GKE. |
| `compute.firewalls.*` (create, get, list, update, delete) | Firewall rules around GKE + Cloud SQL. |
| `compute.disks.*` (create, get, list, update, delete, use, useReadOnly, setLabels, getIamPolicy, setIamPolicy) | OpenSearch persistent disks. |
| `compute.globalAddresses.*` + `compute.addresses.*` | Private Service Connect endpoints, Grafana static IP, Cloud SQL private-IP allocation range. |
| `compute.globalForwardingRules.*` + `compute.forwardingRules.*` | PSC forwarding rule. |
| `compute.routers.*` + `compute.routes.*` | NAT + custom routes. |
| `compute.regions.*`, `compute.zones.*`, `compute.machineTypes.*`, `compute.diskTypes.*` | Reads for GKE planning. |
| `compute.operations.*`, `compute.globalOperations.*`, `compute.regionOperations.*`, `compute.zoneOperations.*` | Polling asynchronous compute operations. |
| `compute.projects.get` | Quota checks, default-network lookups. |

Note: `compute.instances.*` is intentionally NOT granted. Home does not create Compute Engine VMs directly; GKE manages its own node VMs. If a future feature introduces direct VM provisioning, `compute.instances.*` will be added.

## GKE (Kubernetes Engine)

Used by `gke.tf` to provision the GKE private cluster and its 2 node pools.

| Permission | Rationale |
|---|---|
| `container.clusters.{create, get, list, update, delete, getCredentials}` | Cluster lifecycle + kubeconfig generation for Home's `GkeKubeConfigGenerator`. |
| `container.operations.{get, list}` | Polling async cluster operations. |

## Cloud SQL

Used by `databases.tf` via the `terraform-google-modules/sql-db` module to provision the PostgreSQL 17 instance.

| Permission | Rationale |
|---|---|
| `cloudsql.instances.{create, get, list, update, delete, failover, restart}` | Instance lifecycle. |
| `cloudsql.databases.{create, get, list, update, delete}` | DB creation inside the instance. |
| `cloudsql.users.{create, delete, list, update}` | Creating the application user. |
| `cloudsql.sslCerts.{create, delete, get, list}` | SSL certificate rotation. |
| `cloudsql.backupRuns.{create, delete, get, list}` | Backup management. |

## Memorystore Redis

Used by `databases.tf` to provision a STANDARD_HA Redis 7.0 instance.

| Permission | Rationale |
|---|---|
| `redis.instances.{create, get, list, update, delete}` | Instance lifecycle. |
| `redis.operations.{get, list}` | Polling async ops. |

## Certificate Manager

Used by `certificate-manager.tf` for the managed SSL certificate, DNS authorization, and certificate map/entry binding to the GKE Gateway.

| Permission | Rationale |
|---|---|
| `certificatemanager.certs.{create, get, list, update, delete}` | Managed certificate lifecycle. |
| `certificatemanager.dnsauthorizations.{create, get, list, update, delete}` | Domain validation. |
| `certificatemanager.certmaps.{create, get, list, update, delete}` | Certificate map for Gateway. |
| `certificatemanager.certmapentries.{create, get, list, update, delete}` | Map entries per domain. |
| `certificatemanager.locations.{get, list}` | Listing regions where CM is available. |
| `certificatemanager.operations.{get, list, cancel, delete}` | Async op polling. |

## Vertex AI

Used by Home for model inference calls via `aiplatform.googleapis.com`.

| Permission | Rationale |
|---|---|
| `aiplatform.models.{list, get, predict}` | Reading model metadata + invoking prediction. |
| `aiplatform.endpoints.{list, get, predict}` | Calling deployed endpoints. |

## Service Networking

Used by `databases.tf` for VPC peering that enables private-IP access to Cloud SQL.

| Permission | Rationale |
|---|---|
| `servicenetworking.services.{addPeering, deleteConnection, get, use}` | `google_service_networking_connection` resource. |

## Project-level reads

| Permission | Rationale |
|---|---|
| `resourcemanager.projects.get` | Reading project metadata (project number, parent). |
| `resourcemanager.projects.getIamPolicy` | Reading project IAM during refresh. |
| `iam.roles.get`, `iam.roles.list` | Reading the custom roles this module creates (introspection). |

## Explicitly NOT granted

- `roles/owner`, `roles/editor`, any predefined `*.admin` role.
- `serviceusage.services.{enable, disable}` — the module enables APIs at bootstrap; the deployer cannot change API state.
- `resourcemanager.projects.{create, delete, move, setIamPolicy, update}` — the deployer cannot change the project itself.
- `billing.*`.
- `orgpolicy.*`, `accesscontextmanager.*`.
- `iam.roles.{create, update, delete}` — the deployer cannot modify its own role definitions.
- Cloud KMS, Cloud Build, Cloud Functions, Cloud Run, App Engine, BigQuery, Dataflow, Cloud Composer.
