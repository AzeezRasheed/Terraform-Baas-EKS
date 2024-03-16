locals {
  baas_dev_vpc_us               = data.terraform_remote_state.baas_dev_vpc_us.outputs.vpc
  ipv4_cidr_block               = cidrsubnet(local.baas_dev_vpc_us.vpc_cidr_block, 4, 1)
  ipv4_cidr_intra_subnets_block = cidrsubnet(local.baas_dev_vpc_us.vpc_cidr_block, 6, 8)

  tgw    = data.terraform_remote_state.baas_shared_tgw_us.outputs
  tgw_id = local.tgw.transit_gateway_id

  baas_shared_vpc_us            = data.terraform_remote_state.baas_shared_vpc_us.outputs.vpc
  baas_shared_vpc_us_cidr_block = local.baas_shared_vpc_us.vpc_cidr_block

  baas_shared_vpn_cidr = data.terraform_remote_state.baas_shared_vpn.outputs.ipv4_cidr_block

  baas_eks_oidc_id = split("/", module.eks.oidc_provider_arn)[length(split("/", module.eks.oidc_provider_arn)) - 1]
}

data "aws_ecrpublic_authorization_token" "token" {}

################################################################################
# Networking
################################################################################

module "eks_node_subnets" {
  ## https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest
  ## https://github.com/cloudposse/terraform-aws-dynamic-subnets
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  name                        = "eks-nodes"
  availability_zones          = var.availability_zones
  vpc_id                      = local.baas_dev_vpc_us.vpc_id
  igw_id                      = [local.baas_dev_vpc_us.igw_id]
  ipv4_cidr_block             = [local.ipv4_cidr_block]
  max_subnet_count            = length(var.availability_zones)
  private_route_table_enabled = false
  public_subnets_enabled      = false
  nat_gateway_enabled         = false
  nat_instance_enabled        = false

  tags = merge(module.naming.tags, { "kubernetes.io/cluster/${module.naming.id}" = "owned" }, { "karpenter.sh/discovery" = module.naming.id })

  context = module.naming.context
}

module "eks_cp_subnets" {
  ## https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest
  ## https://github.com/cloudposse/terraform-aws-dynamic-subnets
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  name                        = "eks-control-plane"
  availability_zones          = var.availability_zones
  vpc_id                      = local.baas_dev_vpc_us.vpc_id
  igw_id                      = [local.baas_dev_vpc_us.igw_id]
  ipv4_cidr_block             = [local.ipv4_cidr_intra_subnets_block]
  max_subnet_count            = length(var.availability_zones)
  private_route_table_enabled = false
  public_subnets_enabled      = false
  nat_gateway_enabled         = false
  nat_instance_enabled        = false

  tags = merge(module.naming.tags, { "kubernetes.io/cluster/${module.naming.id}" = "owned" })

  context = module.naming.context
}

################################################################################
# Kubernetes cluster
################################################################################

module "eks" {
  ## https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  ## https://github.com/terraform-aws-modules/terraform-aws-eks
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name              = module.naming.id
  cluster_version           = var.cluster_version
  vpc_id                    = local.baas_dev_vpc_us.vpc_id
  subnet_ids                = module.eks_node_subnets.private_subnet_ids
  control_plane_subnet_ids  = module.eks_cp_subnets.private_subnet_ids
  cluster_enabled_log_types = var.kubernetes_cluster_enabled_log_types

  cluster_addons = {
    kube-proxy = {
      enabled = true
      version = var.kube_proxy_version
    }
    vpc-cni = {
      enabled = true
      version = var.vpc_cni_version
    }
    aws-ebs-csi-driver = {
      enabled                  = true
      version                  = var.ebs_csi_version
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
    coredns = {
      enabled = true
      version = var.coredns_version
      configuration_values = jsonencode({
        computeType = "Fargate"
        # Ensure that we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }
  }

  # manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  fargate_profiles = {
    fargate-compute-type = {
      selectors = [
        { namespace = "*", labels = { compute-type = "fargate" } }
      ]
    }
    fargate-core-dns = {
      selectors = [
        { namespace = "kube-system", labels = { "k8s-app" = "kube-dns" } }
      ]
    }
  }

  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description = "VPN to cluster API"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [local.baas_shared_vpn_cidr]
    }
  }

  node_security_group_tags = { "karpenter.sh/discovery" = module.naming.id }
  tags                     = module.naming.tags

  # tags = merge(local.tags, {
  #   # NOTE - if creating multiple security groups with this module, only tag the
  #   # security group that Karpenter should utilize with the following tag
  #   # (i.e. - at most, only one security group should have this tag in your account)
  #   "karpenter.sh/discovery" = module.naming.id
  # })
}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  ## https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter
  ## https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v19.16.0/modules/karpenter
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.16.0"

  cluster_name                    = module.eks.cluster_name
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${var.karpenter_helm_release_namespace}:${var.karpenter_helm_release_name}"]

  iam_role_additional_policies = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  ]

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  }

  tags = module.naming.tags

  // IMPORTANT: For spot instance run this command: aws iam create-service-linked-role --aws-service-name spot.amazonaws.com --profile .... || true
}

################################################################################
# External Secrets
################################################################################

resource "helm_release" "external_secrets" {
  namespace        = "tech"
  create_namespace = true

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "v0.9.5"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets_reader_role.arn
  }
}

resource "kubectl_manifest" "external_secrets_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: SecretStore
    metadata:
      name: secretstore
      namespace: tech
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${var.region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
  YAML
}
