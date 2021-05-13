# Terraform minimum pessimistic version

data "aws_eks_cluster" "masters" {
  name = aws_eks_cluster.masters.id
}

data "aws_eks_cluster_auth" "masters_auth" {
  name = aws_eks_cluster.masters.id
}

provider "kubernetes" {
  version                = "~> 2.1"
  host                   = data.aws_eks_cluster.masters.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.masters.certificate_authority[0].data)
  #load_config_file       = false
  token                  = data.aws_eks_cluster_auth.masters_auth.token
}

# Template provider minimum pessimistic version
provider "template" {
  version = "~> 2.1"
}

provider "helm" {
  version = "~> 1.3.0"
  kubernetes {
    host                   = data.aws_eks_cluster.masters.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.masters.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.masters_auth.token
  }
}
