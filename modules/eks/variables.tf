# -------------------------------------------------------------
# Network variables
# -------------------------------------------------------------

variable "vpc_id" {
  description = "The ID of the VPC where we are deploying the EKS cluster"
}

variable "vpc_cidr" {
  description = "The CIDR range used in the VPC"
}

variable "public_subnets_ids" {
  description = "The IDs of at least two public subnets for the K8S control plane ENIs"
  type        = list(string)
}

variable "private_subnets_ids" {
  description = "The IDs of at least two private subnets to deploy the K8S workers in"
  type        = list(string)
}

# -------------------------------------------------------------
# EKS variables
# -------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the EKS cluster"
}

variable "amzn_eks_worker_ami_name" {
  description = "The name of the AMI to be used. Right now only supports Amazon Linux2 based EKS worker AMI"
}

variable "k8s_version" {
  description = "Desired Kubernetes master version. If you do not specify a value, the latest available version is used."
  default     = ""
}

variable "cluster_log_retention_days" {
  description = "Desired Kubernetes control plane logs retention days."
  type        = string
  default     = ""
}

variable "cluster_log_types" {
  description = "Desired Kubernetes control plane components that will log events to CloudWatch Logs."
  type        = list(string)
  default     = []
}

variable "encrypted_boot_volume" {
  description = "If true, an encrypted EKS AMI will be created to support encrypted boot volumes"
}

variable "keypair_name" {
  description = "The name of an existing key pair to access the K8S workers via SSH"
  default     = ""
}

variable "boot_volume_type" {
  description = "The type of volume to allocate [gp2|io1]"
  default     = "gp2"
}

variable "iops" {
  description = "The amount of provisioned IOPS if volume type is io1"
  default     = 0
}

variable "boot_volume_size" {
  description = "The size of the root volume in GBs"
  default     = 200
}

variable "node_groups" {
  type = map(object({
    name                        = string
    scaling_config_desired_size = number
    scaling_config_max_size     = number
    scaling_config_min_size     = number
    ami_type                    = string
    disk_size                   = number
    instance_types              = list(string)
  }))
  description = "Map of node groups to associate to the EKS cluster"
  default     = {}
}

variable "lb_target_group" {
  description = "The App LB target groups ARNs we want this AutoScaling Group belongs to"
  type        = list(string)
  default     = [""]
}

variable "map_users" {
  description = "A list of maps with the IAM users allowed to access EKS"
  type = list(object({
    user_arn = string
    username = string
    group    = string
  }))
  default = []
  # example:
  #
  #  map_users = [
  #    {
  #      user_arn = "arn:aws:iam::<aws-account>:user/JohnSmith"
  #      username = "john"
  #      group    = "system:masters" # cluster-admin
  #    },
  #    {
  #      user_arn = "arn:aws:iam::<aws-account>:user/PeterMiller"
  #      username = "peter"
  #      group    = "ReadOnlyGroup"  # custom role granting read-only permissions
  #    }
  #  ]
  #
}

variable "map_roles" {
  description = "A list of maps with the roles allowed to access EKS"
  type = list(object({
    role_arn = string
    username = string
    group    = string
  }))
  default = []
  # example:
  #
  #  map_roles = [
  #    {
  #      role_arn = "arn:aws:iam::<aws-account>:role/ReadOnly"
  #      username = "john"
  #      group    = "system:masters" # cluster-admin
  #    },
  #    {
  #      role_arn = "arn:aws:iam::<aws-account>:role/Admin"
  #      username = "peter"
  #      group    = "ReadOnlyGroup"  # custom role granting read-only permissions
  #    }
  #  ]
  #
}

variable "auto_scaler_policy" {
  description = "True if we want to create the policy needed by cluster autoscaler"
  default     = true
}

variable "external_dns_policy_local_access" {
  description = "True if we want to create the policy needed by external DNS to access a hosted zone in the same account"
  default     = true
}

variable "external_dns_cross_account_access" {
  description = "If true, a policy will be attached to the EKS worker role allowing the sts:AssumeRole API call"
  default     = false
}

variable "remote_account_id" {
  description = "The AWS account ID where we created the cross-account role externalDNS will assume"
  default     = "111111111111"
}

variable "remote_r53_role_name" {
  description = "The role name created in a remote AWS account we want externalDNS to assume"
  default     = "update-route53-records"
}

variable "docker_registry_secret" {
  description = "True if we want to create a secret object to pull images from Docker Hub"
  default     = false
}

variable "docker_secret_name" {
  description = "The name of the secret object to create in the k8s cluster"
  default     = "docker-registry"
}

variable "docker_server" {
  description = "Server location for Docker registry"
  default     = "https://index.docker.io/v1/"
}

variable "docker_username" {
  description = "Username for Docker registry authentication"
  default     = "docker_username"
}

variable "docker_encrypted_password" {
  description = "The KMS encrypted password (ciphertext) of the docker user"
  default     = ""
}

variable "docker_email" {
  description = "The email registered in the DockerHub account"
  default     = ""
}

variable "docker_secret_namespace" {
  description = "The namespace where to create the docker-registry secret"
  default     = "default"
}

# -------------------------------------------------------------
# Workers variables
# -------------------------------------------------------------

variable "lt_workers_configuration" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates."
  type        = any
  default     = []

  # Example:
  # lt_workers_configuration = [{
  #   name                    = "spot"
  #   min_size                = 1
  #   desired_capacity        = 1
  #   max_size                = 4
  #   node_labels             = "spot=true"
  #   override_instance_types = ["r4.xlarge", "r4.2xlarge", "r5.xlarge", "r5.2xlarge", "t3.2xlarge", "t3a.2xlarge"]
  # }]
}

variable "worker_role_additional_policies" {
  description = "List of IAM policies ARNs to attach to the workers role"
  type        = list(string)
  default     = []
}

variable "asg_enabled_metrics" {
  description = "Listo of ASG CloudWatch metrics to be enabled"
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]
}

# -------------------------------------------------------------
# Security variables
# -------------------------------------------------------------

variable "allow_app_ports" {
  description = "A list of TCP ports to open in the K8S workers SG for instances/services in the VPC"
  type        = list(string)
  default     = ["22"]
}

# -------------------------------------------------------------
# Tagging
# -------------------------------------------------------------

variable "tags" {
  description = "A map of tags to add to the EKS service"
  type        = map(string)
  default     = {}
}

variable "asg_tags" {
  description = "A map of tags to add to the autoscaling group if using K8S autoscaler"
  type        = map(string)
  default     = {}
}

# -------------------------------------------------------------
# Environment
# -------------------------------------------------------------

variable "environment" {
  description = "The environment name"
  type        = string
}

# -------------------------------------------------------------
# Namespace
# -------------------------------------------------------------
variable "create_environment_namespace" {
  description = "Create a default namespace matching the environment name"
  type        = string
  default     = true
}

variable "create_metrics_namespace" {
  description = "Create a metrics namespace for the metrics server"
  type        = string
  default     = true
}

variable "additional_namespaces" {
  description = "A list of additional namespaces to create in cluster"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------
# Helm charts settings
# -------------------------------------------------------------

variable "charts" {
  description = "A map of values needed to create a new helm release"
  type        = any
  default     = {}
  # example:
  #
  # charts = {
  # "nginx-test" = {
  #   repository       = "https://charts.bitnami.com/bitnami"
  #   chart            = "nginx"
  #   namespace        = "devops-testing-helm"
  #   version          = "6.2.0"
  #   values           = ["${path.cwd}/helm_values/chart/values.yaml"]
  #   create_namespace = true
  #   set_sensitive    = [
  #     {
  #       name = "nameOverride"
  #       value = data.aws_kms_secrets.helm-secrets.plaintext["name-override"]
  #       type = "string"
  #     },
  #     {
  #       name = "pullPolicy"
  #       value = data.aws_kms_secrets.helm-secrets.plaintext["pull-policy"]
  #       type = "string"
  #     }
  #   ]
  # }
  #}
}

variable deploy_charts {
  description = "Enables the helm charts deployment"
  type        = bool
  default     = false
}

variable release_lint {
  description = "Run the helm chart linter during the plan"
  type        = bool
  default     = false
}

variable release_wait {
  description = "Will wait until all resources are in a ready state before marking the release as successful. It will wait for as long as timeout"
  type        = bool
  default     = true
}

variable release_timeout {
  description = "Time in seconds to wait for any individual kubernetes operation (like Jobs for hooks)"
  type        = number
  default     = 300
}

variable "endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  default     = true
}

variable "endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  default     = false
}

variable "cluster_autoscaler" {
  description = "Enable/disable the usage of cluster autoscaler tags and labels to use Cluster Autoscaler"
  type        = bool
  default     = false
}
