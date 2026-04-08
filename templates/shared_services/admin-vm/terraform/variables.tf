variable "tre_id" {
  type        = string
  description = "Unique TRE ID"
}

variable "kv_name_override" {
  type        = string
  description = "Optional override for the core Key Vault name. Leave empty to use the default name kv-<tre_id>."
  default     = ""
}

variable "tre_resource_id" {
  type        = string
  description = "Resource ID"
}

variable "admin_jumpbox_vm_sku" {
  type = string
}

variable "enable_cmk_encryption" {
  type    = bool
  default = false
}

variable "key_store_id" {
  type = string
}

variable "image_gallery_id" {
  type = string
}

variable "image" {
  type = string
}
