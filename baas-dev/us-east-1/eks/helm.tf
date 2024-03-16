################################################################################
# ALB
################################################################################

resource "helm_release" "alb" {
  // https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/helm/aws-load-balancer-controller/values.yaml
  namespace        = "tech"
  create_namespace = true

  name       = "alb"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.1"

  set {
    name  = "clusterName"
    value = module.naming.id
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = local.baas_dev_vpc_us.vpc_id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_role.arn
    type  = "string"
  }

  #   set {
  #     name  = "additionalLabels.eks\\.amazonaws\\.com/compute-type"
  #     value = "fargate"
  #   }

  values = [
    file("helm/alb.values.yaml")
  ]

  depends_on = [helm_release.karpenter]
}

################################################################################
# Karpenter
################################################################################

resource "helm_release" "karpenter" {
  // https://github.com/aws/karpenter/blob/main/charts/karpenter/values.yaml
  namespace        = var.karpenter_helm_release_namespace
  create_namespace = true

  name                = var.karpenter_helm_release_name
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.21.1"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }

  set {
    name  = "podLabels.compute-type"
    value = "fargate"
  }

  values = [
    file("helm/karpenter.values.yaml")
  ]

  #   lifecycle {
  #     ignore_changes = [
  #       repository_password
  #     ]
  #   }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(var.availability_zones)}
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [c5, c5a, c6, c6a, c6i, m5, m5a, m6, m6a, m6i, t3, t3a]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: [large, xlarge, 2xlarge]
        - key: kubernetes.io/os	
          operator: In	
          values:	[linux]	
        - key: kubernetes.io/arch	
          operator: In	
          values:	[amd64]
    #   limits:
    #     resources:
    #       cpu: 2000
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      amiFamily: Bottlerocket
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 5Gi
            volumeType: gp3
            deleteOnTermination: true
            encrypted: true
        - deviceName: /dev/xvdb
          ebs:
            volumeSize: 20Gi
            volumeType: gp3
            deleteOnTermination: true
            encrypted: true
      userData:  |
        [settings.kubernetes]
        "kube-api-qps" = 30
        "shutdown-grace-period" = "30s"
        "shutdown-grace-period-for-critical-pods" = "30s"
        [settings.kubernetes.eviction-hard]
        "memory.available" = "10%"  
  YAML

  depends_on = [helm_release.karpenter]
}

# Example deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
# and starts with zero replicas
# resource "kubectl_manifest" "karpenter_example_deployment" {
#   yaml_body = <<-YAML
#     apiVersion: apps/v1
#     kind: Deployment
#     metadata:
#       name: inflate
#     spec:
#       replicas: 0
#       selector:
#         matchLabels:
#           app: inflate
#       template:
#         metadata:
#           labels:
#             app: inflate
#         spec:
#           terminationGracePeriodSeconds: 0
#           containers:
#             - name: inflate
#               image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
#               resources:
#                 requests:
#                   cpu: 1
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }

################################################################################
# Gitlab Runner
################################################################################

data "aws_ssm_parameter" "gitlab_runner_token" {
  name = "/eks/gitlab_runner_token"
}

resource "helm_release" "gitlab_runner" {
  // https://gitlab.com/gitlab-org/charts/gitlab-runner
  namespace        = "tech"
  create_namespace = true

  name       = "gitlab-runner"
  repository = "https://charts.gitlab.io"
  chart      = "gitlab-runner"
  version    = "0.57.0"

  set {
    name  = "serviceAccountAnnotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.gitlab_runner.arn
  }

  set {
    name  = "runnerToken"
    value = data.aws_ssm_parameter.gitlab_runner_token.value
  }

  values = [
    file("helm/gitlab-runner.values.yaml")
  ]

  depends_on = [helm_release.karpenter, aws_iam_role.gitlab_runner]
}

################################################################################
# ArgoCD
################################################################################

#resource "helm_release" "argo_cd" {
#  namespace        = "tech"
#  create_namespace = true
#
#  name       = "argo-cd"
#  repository = "https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd"
#  chart      = "argo-cd"
#  version    = "2.8.4"
#
#  values = [
#    file("helm/argo.values.yaml")
#  ]
#}
