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

variable "ent_home_aws_role_name" {
  description = "IAM role name in Ent's AWS account that will be federated to impersonate the deployer service account."
  type        = string
  default     = "HomeProdAssumeAdmin"
}

variable "deployer_sa_id" {
  description = "Account ID (the part before @) for the service account Ent Home will impersonate."
  type        = string
  default     = "ent-home-deployer"
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
  description = "Resource-name prefix that IAM Conditions use to scope the deployer to Ent-managed resources. Must match ent-platform's local.name_prefix formula. Override only if ent-platform changes the prefix shape."
  type        = string
  default     = "e"
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
