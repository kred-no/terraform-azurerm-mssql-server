////////////////////////
// Config (Local)
////////////////////////

locals {
  name                  = "private-link-service"
  disable_outbound_snat = false
}

////////////////////////
// Config
////////////////////////

variable "tags" {}
variable "virtual_network" {}
variable "subnet" {}
variable "network_interface" {}
variable "network_security_group" {}
variable "application_security_group" {}
variable "sku" {}
variable "domain_name_label" {}
