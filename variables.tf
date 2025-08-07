variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}
variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}
variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}
variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}
variable "name_prefix" {
  default     = "postgresqlfs"
  description = "Prefix of the resource name."
}
variable "location" {
  default     = "eastus"
  description = "Location of the resource."
}
