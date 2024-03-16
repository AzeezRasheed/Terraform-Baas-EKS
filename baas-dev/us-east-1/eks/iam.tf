################################################################################
# ALB
################################################################################

resource "aws_iam_policy" "alb_policy" {
  name   = "AmazonEKSLoadBalancerControllerPolicy"
  policy = data.aws_iam_policy_document.alb_management.json
}

resource "aws_iam_role" "alb_role" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:aud" : "sts.amazonaws.com",
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:sub" : "system:serviceaccount:tech:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_role_policy_attachment" {
  policy_arn = aws_iam_policy.alb_policy.arn
  role       = aws_iam_role.alb_role.name
}

data "aws_iam_policy_document" "alb_management" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    condition {
      test = "StringEquals"
      values = [
        "elasticloadbalancing.amazonaws.com"
      ]
      variable = "iam:AWSServiceName"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:*:*:security-group/*",
    ]
    condition {
      test = "StringEquals"
      values = [
        "CreateSecurityGroup"
      ]
      variable = "ec2:CreateAction"
    }
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = [
      "arn:aws:ec2:*:*:security-group/*",
    ]
    condition {
      test = "Null"
      values = [
        "true"
      ]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test = "Null"
      values = [
        "true"
      ]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    resources = ["*"]
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test = "StringEquals"
      values = [
        "CreateTargetGroup",
        "CreateLoadBalancer"
      ]
      variable = "elasticloadbalancing:CreateAction"
    }
    condition {
      test = "Null"
      values = [
        "false"
      ]
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

################################################################################
# Gitlab Runner
################################################################################

data "aws_iam_policy_document" "gitlab_runner_cf_invalidation" {
  statement {
    actions = [
      "cloudfront:CreateInvalidation",
    ]
    resources = ["arn:aws:cloudfront::*:distribution/*"]
  }
}

resource "aws_iam_policy" "gitlab_runner_cf_invalidation" {
  name   = "GitlabRunnerCloudFrontInvalidation"
  policy = data.aws_iam_policy_document.gitlab_runner_cf_invalidation.json
}

resource "aws_iam_role" "gitlab_runner" {
  name = "GitlabRunnerRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:aud" : "sts.amazonaws.com",
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:sub" : "system:serviceaccount:tech:gitlab-runner"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_runner_cf_invalidation" {
  policy_arn = aws_iam_policy.gitlab_runner_cf_invalidation.arn
  role       = aws_iam_role.alb_role.name
}

resource "aws_iam_role_policy_attachment" "gitlab_runner_cf_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/CloudFrontReadOnlyAccess"
  role       = aws_iam_role.alb_role.name
}

################################################################################
# EBS CSI
################################################################################

data "aws_iam_policy_document" "ebs_csi_encryption" {

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["arn:aws:kms:us-east-1:*:key/*"]
  }
}

resource "aws_iam_policy" "ebs_csi_encryption" {
  name   = "AmazonEKS_EBS_Encryption"
  policy = data.aws_iam_policy_document.ebs_csi_encryption.json
}

resource "aws_iam_role" "ebs_csi_role" {
  name = "AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:aud" : "sts.amazonaws.com",
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

resource "aws_iam_role_policy_attachment" "ebs_csi_role_encryption" {
  policy_arn = aws_iam_policy.ebs_csi_encryption.arn
  role       = aws_iam_role.ebs_csi_role.name
}

################################################################################
# External Secrets
################################################################################

data "aws_iam_policy_document" "external_secrets_reader_policy_document" {
  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["arn:aws:kms:us-east-1:*:key/*"]
  }
}

resource "aws_iam_policy" "external_secrets_reader_policy" {
  name   = "ExternalSecrets_Reader_Policy"
  policy = data.aws_iam_policy_document.external_secrets_reader_policy_document.json
}

resource "aws_iam_role" "external_secrets_reader_role" {
  name = "ExternalSecrets_Reader_Role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:aud" : "sts.amazonaws.com",
            "oidc.eks.${var.region}.amazonaws.com/id/${local.baas_eks_oidc_id}:sub" : "system:serviceaccount:tech:external-secrets"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets_reader_role_attachment" {
  policy_arn = aws_iam_policy.external_secrets_reader_policy.arn
  role       = aws_iam_role.external_secrets_reader_role.name
}
