variable "account" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "bucket_versioning" {
  type = bool
}

variable "bucket_object_lock" {
  type = bool
}

variable "bucket_object_lock_default_retention" {
  type    = number
  default = -1
}

variable "bucket_server_access_logs_bucket" {
  type    = string
  default = ""
}

variable "bucket_server_access_logs_prefix" {
  type    = string
  default = ""
}

variable "bucket_inventory_arn" {
  type    = string
  default = ""
}

variable "bucket_public_access" {
  type = object({
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)
  })

  default = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

variable "bucket_enforce_ssl" {
  type    = bool
  default = true
}

variable "bucket_object_ownership" {
  type    = string
  default = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "ObjectWriter", "BucketOwnerPreferred"], var.bucket_object_ownership)
    error_message = "Allowed values for bucket_object_ownership are \"BucketOwnerEnforced\", \"ObjectWriter\", or \"BucketOwnerPreferred\"."
  }
}

variable "bucket_cors_configuration" {
  type = list(object({
    allowed_headers = optional(list(string), null)
    allowed_methods = optional(list(string), null)
    allowed_origins = optional(list(string), null)
    expose_headers  = optional(list(string), null)
    max_age_seconds = optional(number, null)
  }))

  default = []

}

variable "bucket_lifecycle_rules" {
  type = list(object({
    id = string
    expiration = optional(object({
      date                         = optional(string, null)
      days                         = optional(number, null)
      expired_object_delete_marker = optional(bool, null)
    }), null)

    filter = object({
      prefix = optional(string, null)
    })
  }))

  default = []
}

variable "bucket_policies" {
  type    = list(string)
  default = []
}

variable "kms_key_policies" {
  type    = list(string)
  default = []
}
