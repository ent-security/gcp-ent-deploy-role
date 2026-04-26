output "deployer_sa_email" {
  description = "Email of the deployer service account. Paste this into Ent's GCP connection panel. In external-SA mode this echoes back `var.existing_deployer_sa_email`."
  value       = local.deployer_sa_email
}

output "wif_provider_resource_name" {
  description = "Full resource name of the Workload Identity provider. Paste this into Ent's GCP connection panel. Null when `existing_deployer_sa_email` is set (the WIF pool lives elsewhere)."
  value       = one(google_iam_workload_identity_pool_provider.aws[*].name)
}

output "wif_pool_resource_name" {
  description = "Full resource name of the Workload Identity pool (for reference). Null when `existing_deployer_sa_email` is set."
  value       = one(google_iam_workload_identity_pool.ent_home[*].name)
}

output "project_id" {
  description = "The GCP project ID that was bootstrapped."
  value       = var.project_id
}

output "custom_role_scoped_name" {
  description = "Full name of the scoped custom role (for reference)."
  value       = google_project_iam_custom_role.scoped.name
}

output "custom_role_unscoped_name" {
  description = "Full name of the unscoped custom role (for reference)."
  value       = google_project_iam_custom_role.unscoped.name
}
