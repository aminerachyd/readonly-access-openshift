terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

provider "kubernetes" {
  host     = var.cluster-host
  token    = var.cluster-token
  insecure = true
}

provider "kubectl" {
  host     = var.cluster-host
  token    = var.cluster-token
  insecure = true
}
