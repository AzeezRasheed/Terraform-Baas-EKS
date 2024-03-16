variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "A list of availability zones names or ids in the region"
}

variable "cluster_version" {
  type        = string
  description = "The version of Kubernetes to use for the EKS cluster"
}

variable "kube_proxy_version" {
  description = "The version of kube-proxy to use for the EKS cluster"
  type        = string
}

variable "coredns_version" {
  type        = string
  description = "The version of coredns to use for the EKS cluster"
}

variable "vpc_cni_version" {
  type        = string
  description = "The version of the VPC CNI plugin to use for the EKS cluster"
}

variable "ebs_csi_version" {
  type        = string
  default     = "v1.23.0"
  description = "The version of the EBS CSI plugin to use for the EKS cluster"
}

variable "kubernetes_namespace" {
  type        = string
  default     = "default"
  description = "The namespace to deploy the Kubernetes resources into"
}

variable "kubernetes_labels" {
  type        = map(string)
  default     = {}
  description = "A map of labels to apply to the Kubernetes resources"
}

variable "kubernetes_cluster_enabled_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  description = "A list of the desired control plane logging to enable"
}

variable "karpenter_helm_release_name" {
  type        = string
  default     = "karpenter"
  description = "Name of karpenter helm release"
}

variable "karpenter_helm_release_namespace" {
  type        = string
  default     = "tech"
  description = "Karpenter helm release namespace"
}