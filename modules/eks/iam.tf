# --------------------------------------------------------------------
# IAM Role and Policies for EKS (Kubernetes Control Plane)
# --------------------------------------------------------------------

data "aws_iam_policy_document" "k8s_masters_role_policy_document" {
  statement {
    sid    = "EKSMasterTrustPolicy"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k8s_masters_role" {
  name               = "${var.environment}-EksMastersRole"
  assume_role_policy = data.aws_iam_policy_document.k8s_masters_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.k8s_masters_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.k8s_masters_role.name
}

# --------------------------------------------------------------------
# IAM Role and Policies for EKS workers
# --------------------------------------------------------------------

data "aws_iam_policy_document" "k8s_workers_role_role_policy_document" {
  statement {
    sid    = "EKSWorkerTrustPolicy"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k8s_workers_role" {
  name               = "${var.environment}-EksWorkersRole"
  assume_role_policy = data.aws_iam_policy_document.k8s_workers_role_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.k8s_workers_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.k8s_workers_role.name
}

resource "aws_iam_role_policy_attachment" "container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.k8s_workers_role.name
}

resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = length(var.worker_role_additional_policies)
  policy_arn = var.worker_role_additional_policies[count.index]
  role       = aws_iam_role.k8s_workers_role.name
}

resource "aws_iam_instance_profile" "iam_workers_profile" {
  name = "${var.environment}-EksWorkersProfile"
  role = aws_iam_role.k8s_workers_role.name
}

# --------------------------------------------------------------------
# Additional IAM Policies for EKS workers
# --------------------------------------------------------------------

## Policy to allow the K8S cluster auto-scaler feature to adjust the size of an ASG
data "aws_iam_policy_document" "autoscaling_policy" {
  count = var.auto_scaler_policy ? 1 : 0

  statement {
    sid    = "AutoScalingReadAccessForK8s"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "AutoScalingWriteAccessForK8s"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]

    resources = aws_autoscaling_group.lt-workers.*.arn
  }
}

resource "aws_iam_policy" "autoscaler_policy" {
  count = var.auto_scaler_policy ? 1 : 0

  name        = "${var.environment}-EksClusterAutoscaler"
  description = "Allows K8S cluster auto-scaler to adjust the ASG size"
  policy      = data.aws_iam_policy_document.autoscaling_policy[0].json
}

resource "aws_iam_role_policy_attachment" "autoscaler_policy" {
  count = var.auto_scaler_policy ? 1 : 0

  policy_arn = aws_iam_policy.autoscaler_policy[count.index].arn
  role       = aws_iam_role.k8s_workers_role.name
}

## Policy to allow external-dns to update recordsets in a given
## Hosted Zone in the same AWS account
data "aws_iam_policy_document" "route53_recordsets_policy" {
  count = var.external_dns_policy_local_access ? 1 : 0

  statement {
    sid    = "ExternalDNSChangeResourceRecordSets"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      "arn:aws:route53:::hostedzone/*",
    ]
  }

  statement {
    sid    = "ExternalDNSListRoute53Resources"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "external_dns_policy" {
  count = var.external_dns_policy_local_access ? 1 : 0

  name        = "${var.environment}-EksExternalDNS"
  description = "Allow external-dns to update recordsets in Route53 hosted zones"
  policy      = data.aws_iam_policy_document.route53_recordsets_policy[0].json
}

resource "aws_iam_role_policy_attachment" "external_dns_policy" {
  count = var.external_dns_policy_local_access ? 1 : 0

  policy_arn = aws_iam_policy.external_dns_policy[0].arn
  role       = aws_iam_role.k8s_workers_role.name
}

## Policy to allow external-dns to update recordsets in a given
## Hosted Zone in a remote AWS account (by assuming a cross-account role)
data "aws_iam_policy_document" "external_dns_cross_account_policy" {
  count = var.external_dns_cross_account_access ? 1 : 0

  statement {
    sid    = "ExternalDNSChangeRemoteRecordSets"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    resources = [
      "arn:aws:iam::${var.remote_account_id}:role/${var.remote_r53_role_name}",
    ]
  }
}

resource "aws_iam_policy" "external_dns_cross_account_policy" {
  count = var.external_dns_cross_account_access ? 1 : 0

  name        = "${var.environment}-EksExternalDNSRemoteAccess"
  description = "Allow external-dns to update records in remote Route53 hosted zone(s)"
  policy      = data.aws_iam_policy_document.external_dns_cross_account_policy[0].json
}

resource "aws_iam_role_policy_attachment" "external_dns_cross_account_policy" {
  count = var.external_dns_cross_account_access ? 1 : 0

  policy_arn = aws_iam_policy.external_dns_cross_account_policy[0].arn
  role       = aws_iam_role.k8s_workers_role.name
}

data "aws_iam_policy_document" "k8s_ng_role_policy_document" {
  statement {
    sid    = "EKSNodeGroupTrustPolicy"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ng" {
  name               = "${var.environment}-EksNodeGroupRole"
  assume_role_policy = data.aws_iam_policy_document.k8s_ng_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "ng-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ng-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ng-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ng.name
}
