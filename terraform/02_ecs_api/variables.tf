
variable "app" {
  default = "moya"
}

variable "environment" {
  default = "poc"
}

variable "subnets" {
  default = ["subnet-0e4ff2bbc29485dac", "subnet-05ba0b9e6fe80d483"]
}

variable "vpc" {
  default = "vpc-0bdd17808b7cce41a"
}

variable "lb_protocol" {
  default = "TCP"
}

variable "lb_port" {
  default = "80"
}

variable "container_port" {
  default = "80"
}

variable "health_check_interval" {
  default = "30"
}

variable "deregistration_delay" {
  default = "30"
}
