# --------------------------------------------------------------------
# Terraform data sources
# --------------------------------------------------------------------

## Get an Amazon Linux2 image optimized for EKS K8S workers using the given name
data "aws_ami" "amazon_eks_workers" {
  filter {
    name   = "name"
    values = [var.amzn_eks_worker_ami_name]
  }

  owners = ["602401143452", "self"] # Owned by Amazon and current account.
}

# -------------------------------------------------------------
# locals expressions to compute AMI ID and userdata script
# -------------------------------------------------------------

locals {
  ami_id = var.encrypted_boot_volume ? join("", aws_ami_copy.encrypted_eks_ami.*.id) : data.aws_ami.amazon_eks_workers.image_id

  worker_userdata = {
    ## cloud-init script to bootstrap Amazon Linux2 EKS-optimized image
    ## to configure kubeconfig for kubelet
    amazon = <<USERDATA
    #!/bin/bash
    set -o xtrace
    %s # Support for custom startup script
    /etc/eks/bootstrap.sh --kubelet-extra-args '--node-labels=%s --register-with-taints=%s %s' ${var.cluster_name}
USERDATA
  }

  # Docker configuration

  docker_config = {
    (var.docker_server) = {
      email    = var.docker_email
      username = var.docker_username
      password = var.docker_registry_secret && var.docker_encrypted_password != "" ? data.aws_kms_secrets.docker_password.0.plaintext["docker_password"] : ""
    }
  }
}

locals {
  cluster_autoscaler_base_tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "true"
  }

  cluster_autoscaler_lt_label_tags = [for ng in var.lt_workers_configuration :
    {
      "k8s.io/cluster-autoscaler/node-template/label/${element(split("=", lookup(ng, "node_labels", "")), 0)}" = element(split("=", lookup(ng, "node_labels", "")), 1)
    }
  ]

  lt_asg_name_tag = [for ng in var.lt_workers_configuration :
    {
      Name = "${var.cluster_name}-${lookup(ng, "name", "mixed")}-worker"
    }
  ]

  asg_base_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.tags,
    var.asg_tags
  )
}