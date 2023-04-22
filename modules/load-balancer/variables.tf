////////////////////////
// Local
////////////////////////

locals {
  prefix                = "sql-server"
  prefix_length         = 31
  sku                   = "Standard"
  allocation_method     = "Static"
  disable_outbound_snat = false
}

////////////////////////
// External Sources
////////////////////////

variable "tags" {}
variable "pip_prefix" {}
variable "vnet" {}
variable "subnet" {}
variable "nsg" {}
variable "nic" {}
variable "asg" {}

////////////////////////
// Create Resources
////////////////////////

variable "domain_name_label" {}
variable "nat_pool_rules" {}
variable "nat_rules" {}
variable "lb_rules" {}