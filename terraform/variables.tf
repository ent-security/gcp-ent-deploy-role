variable "project_id" {
  description = "GCP project ID into which the Ent deployer will be provisioned. The project must already exist and have billing enabled."
  type        = string
}

variable "ent_home_aws_account_id" {
  description = "AWS account ID of Ent's Home control plane. Provided by Ent. Leave as the placeholder to force an explicit override."
  type        = string
  default     = "000000000000"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.ent_home_aws_account_id))
    error_message = "ent_home_aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "ent_home_aws_role_names" {
  description = "IAM role names in Ent's AWS account that federate to the deployer service account. Include every role the Ent Home control plane may assume when calling this project: the EKS Pod Identity role the ent-home-api pod runs under at runtime (used by deployments) and any human-admin role (e.g. HomeProdAssumeAdmin) used for manual bootstrap or troubleshooting. Provided by Ent. Ignored when `existing_deployer_sa_email` is set."
  type        = set(string)
  default     = []
  # Length validation moved to a precondition on the WIF provider resource so
  # external-SA mode (existing_deployer_sa_email set) does not require this.
}

variable "deployer_sa_id" {
  description = "Account ID (the part before @) for the service account Ent Home will impersonate. Ignored when `existing_deployer_sa_email` is set."
  type        = string
  default     = "ent-home-deployer"
}

variable "existing_deployer_sa_email" {
  description = "Email of an existing service account to bind the deployer roles to. When set, this module skips creating its own deployer SA and Workload Identity Pool/provider — those resources are assumed to exist elsewhere (typically a central platform project whose SA is reused across many tenant projects). When unset (default), the module creates a new SA + WIF pool inside `project_id` (the customer-facing flow). In external-SA mode the module still creates the two custom roles, grants them to the supplied SA, and enables the required APIs."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_deployer_sa_email == "" || can(regex("@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.existing_deployer_sa_email))
    error_message = "existing_deployer_sa_email must be empty or a valid GCP service account email (e.g. my-sa@my-project.iam.gserviceaccount.com)."
  }
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID. Must be unique within the project."
  type        = string
  default     = "ent-home-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Pool provider ID for the AWS identity provider."
  type        = string
  default     = "aws-provider"
}

variable "custom_role_scoped_id" {
  description = "ID for the custom role containing scoped (conditionally bound) permissions."
  type        = string
  default     = "entHomeDeployerScoped"
}

variable "custom_role_unscoped_id" {
  description = "ID for the custom role containing unscoped (unconditionally bound) permissions."
  type        = string
  default     = "entHomeDeployerUnscoped"
}

variable "tenant_name_prefix_glob" {
  description = "Resource-name prefix that IAM Conditions use to scope the deployer to Ent-managed resources. Must match ent-platform's GCP local.name_prefix formula (deploy/tofu/gcp/platform/locals.tf), which starts with the literal \"g\". Override only if ent-platform changes the prefix shape."
  type        = string
  default     = "g"
}

variable "enable_apis" {
  description = "Whether this module should enable the required Google APIs. Set to false if the customer manages API enablement centrally (e.g., via a separate bootstrap pipeline)."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to resources that support them."
  type        = map(string)
  default     = {}
}
