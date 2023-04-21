variable "sku" {
  type    = string
  default = "Standard"
}

variable "domain_name_label" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "virtual_network" {
  type = object({
    name                = string
    resource_group_name = string
    location            = string
  })
}

variable "network_interface" {
  type = object({
    id = string

    ip_configuration = list(object({
      name = string
    }))
  })
}

variable "application_security_group" {
  type = object({
    id = string
  })
}

variable "network_security_group" {
  type = object({
    name = string
    id   = string
  })
}
