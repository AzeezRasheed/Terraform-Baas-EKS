name               = "eks"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
cluster_version    = "1.28"

kube_proxy_version   = "v1.28.1-eksbuild.1"
vpc_cni_version      = "v1.15.0-eksbuild.2"
coredns_version      = "v1.10.1-eksbuild.4"
ebs_csi_version      = "v1.23.0-eksbuild.1"
kubernetes_namespace = "fargate"
