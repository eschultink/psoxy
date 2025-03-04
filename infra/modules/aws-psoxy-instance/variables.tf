variable "aws_account_id" {
  type        = string
  description = "id of aws account in which to provision your AWS infra"
  validation {
    condition     = can(regex("^\\d{12}$", var.aws_account_id))
    error_message = "The aws_account_id value should be 12-digit numeric string."
  }
}

variable "region" {
  type        = string
  description = "region into which to deploy function"
  default     = "us-east-1"
}

variable "function_name" {
  type        = string
  description = "name of function"
}

variable "handler_class" {
  type        = string
  description = "Class to handle the request"
  default     = "co.worklytics.psoxy.Handler"
}

variable "aws_assume_role_arn" {
  type        = string
  description = "role arn"
}

variable "source_kind" {
  type        = string
  description = "kind of source (eg, 'gmail', 'google-chat', etc)"
}

variable "parameters" {
  # see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter#attributes-reference
  type = list(object({
    name    = string
    arn     = string
    version = string
  }))
  description = "System Manager Parameters to expose to function"
}

variable "path_to_repo_root" {
  type        = string
  description = "path root of your checkout; ideally absolute"
}


variable "path_to_function_zip" {
  type        = string
  description = "path to zip archive of lambda bundle"
}

variable "function_zip_hash" {
  type        = string
  description = "hash of base64-encoded zipped lambda bundle"
}

variable "path_to_config" {
  type        = string
  description = "path to config file (usually someting in ../../configs/, eg configs/gdirectory.yaml"
}


variable "example_api_calls" {
  type        = list(string)
  description = "example endpoints that can be called via proxy"
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-sensitive variables to add as an environment variable."
  default     = {}
}
