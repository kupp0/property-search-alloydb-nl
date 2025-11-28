variable "project_id" {
  description = "The ID of the Google Cloud project to create"
  type        = string
}

variable "billing_account_id" {
  description = "The Billing Account ID to associate with the project"
  type        = string
}

variable "region" {
  description = "The region for resources"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The zone for resources"
  type        = string
  default     = "europe-west1-b"
}

variable "alloydb_cluster_id" {
  description = "The ID of the AlloyDB cluster"
  type        = string
  default     = "search-cluster"
}

variable "alloydb_instance_id" {
  description = "The ID of the AlloyDB primary instance"
  type        = string
  default     = "search-primary"
}

variable "db_password" {
  description = "The password for the AlloyDB postgres user"
  type        = string
  sensitive   = true
}

variable "data_store_id" {
  description = "The ID of the Vertex AI Search Data Store"
  type        = string
  default     = "property-listings-ds"
}

variable "data_store_display_name" {
  description = "The display name of the Vertex AI Search Data Store"
  type        = string
  default     = "Property Listings"
}
