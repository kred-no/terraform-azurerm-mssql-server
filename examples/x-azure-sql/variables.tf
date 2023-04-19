variable "subscription_id" {
  description = "Set the subscription for resources (or define environment variable ARM_SUBSCRIPTION_ID)"

  type    = string
  default = null
}

variable "tenant_id" {
  description = "Set the subscription for resources (or define environment variable ARM_TENANT_ID)"

  type    = string
  default = null
}

variable "firewall_rules" {
  type = list(object({
    name             = string
    start_ip_address = string
    end_ip_address   = string
  }))

  default = []
}