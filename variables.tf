variable "cluster-host" {
  description = "Hostname of the cluster"
}

variable "cluster-token" {
  description = "Token of the cluster, needs admin privileges"
}

variable "group-name" {
  description = "Group in which the users will be added"
  default     = "techzone-multiarch-demo"
}

variable "projects" {
  type = list(string)
}
