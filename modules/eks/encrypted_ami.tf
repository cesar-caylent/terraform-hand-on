# --------------------------------------------------------------------
# Terraform data sources
# --------------------------------------------------------------------

data "aws_region" "current" {
}

# --------------------------------------------------------------------
# EKS workers encrypted AMI
# --------------------------------------------------------------------

## Create encrypted AMI only if encryption at rest is enabled
resource "aws_ami_copy" "encrypted_eks_ami" {
  count             = var.encrypted_boot_volume ? 1 : 0
  name              = "encrypted-${var.amzn_eks_worker_ami_name}"
  description       = "${var.amzn_eks_worker_ami_name} encrypted AMI for EKS workers"
  source_ami_id     = data.aws_ami.amazon_eks_workers.image_id
  source_ami_region = data.aws_region.current.name
  encrypted         = true
}

