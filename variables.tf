variable "cluster-host" {
  description = "Hostname of the cluster"
}

variable "cluster-token" {
  description = "Token of the cluster, needs admin privileges"
}

variable "project" {
  description = "Name of the project to run the cronjob"
  default     = "techzone-boutique-dev"
}
