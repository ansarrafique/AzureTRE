variable "tre_id" {
  type = string
}
variable "tre_resource_id" {
  type = string
}
variable "arm_environment" {
  type = string
}
variable "enable_cmk_encryption" {
  type    = bool
  default = false
}
variable "key_store_id" {
  type = string
}

variable "kv_name_override" {
  type        = string
  description = "Optional override for the core Key Vault name. Leave empty to use the default name kv-<tre_id>."
  default     = ""
}
