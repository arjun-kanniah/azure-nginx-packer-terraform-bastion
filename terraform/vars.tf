variable "prefix" {
  description = "The prefix which should be used for all resources in this demo"
  type        = string
  default     = "web-server"
}

variable "packer-prefix" {
  description = "The prefix which should be used for packer image in this demo"
  type        = string
  default     = "web-server-packer"
}

variable "location" {
  description = "The Azure Region in which all resources in this demo should be created."
  type        = string
  default     = "westus2"
}

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(string)
  default = {
    environment = "web-server-project"
  }
}

variable "lb_port" {
    description = "The port that you want to connect from the external load balancer"
    default     = 80
}

variable "application_port" {
    description = "The port that you want to expose to the external load balancer"
    default     = 8080
}

variable "capacity" {
    description = "The number of VMs you want to deploy in the cluster"
    type        = number
    default     = 2
}

variable "username" {
    description = "The deafult username to be used on the VMs"
    type        = string
    default     = "azadmin"
}

variable "password" {
    description = "The deafult password to be used on the VMs"
    type        = string
    default     = "$ecur3Pa$$w0rd"
}