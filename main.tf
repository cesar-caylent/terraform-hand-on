module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = lookup(local.blocks, local.env)
  region               = lookup(local.region, local.env)
  azs                  = ["${lookup(local.region, local.env)}a"]
  public_subnet_cidrs  = lookup(local.public_subnets, local.env)
  private_subnet_cidrs = lookup(local.private_subnets, local.env)
  # Creates a NAT Gateway between private and public subnets
  enable_nat_gw = false
  # Make only a single NAT Gateway for all AZs, rather than 1 for each AZ



  # Security settings: custom ACL rules for public subnets
  allow_inbound_traffic_public_subnet = [
    {
      protocol  = "tcp"
      from_port = 443
      to_port   = 443
      source    = "0.0.0.0/0"
    },
  ]

  # Tagging
  tags = {
    environment = "${local.env}"
    App         = "App1"
  }

  # Tags needed for EKS to identify public and private subnets

  eks_private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

}

module "eks_cluster" {
  source = "./modules/eks"

  # Network settings
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  public_subnets_ids  = module.vpc.public_subnet_ids
  private_subnets_ids = module.vpc.private_subnet_ids

  # EKS settings
  cluster_name = "${local.env}-eks-cluster"
  # The Kubernetes master version
  k8s_version = "1.18"
  # The image to be used for EKS workers;
  amzn_eks_worker_ami_name = "amazon-eks-node-1.18-v20190701"

  # Find available worker AMIs from EC2 > AMI
  keypair_name          = "dev-caylent"
  boot_volume_size      = "20"
  encrypted_boot_volume = "false"

  environment = "test"


  docker_encrypted_password = "test"
  cluster_log_types         = ["api", "audit"]

  lt_workers_configuration = [
    {
      name                    = "spot-node-group"
      min_size                = 1
      max_size                = 2
      override_instance_types = ["t3.small", "t3a.small", "t3.micro", "t3a.micro"]
      node_labels             = "node-type=spot"
      node_taints             = "spot=true:NoSchedule"
    },
  ]

  # Additional tags to be added to the AutoScaling Group (workers)
  /*tags = list(
      tomap({"key", "App", "value", "Web", "propagate_at_launch", true}),
      tomap({"key", "Environment", "value", "development", "propagate_at_launch", true, "${local.env}"})
    )*/
}


