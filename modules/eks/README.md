# Terraform module for AWS EKS service

Terraform module which creates an AWS EKS Kubernetes cluster in a given VPC.

At the moment it only supports Amazon Linux2 image optimized for EKS K8S workers
but the support of Ubuntu 18.04 for EKS workers is planned as a future improvement.

The module supports encryption at rest. In that case the official AMI is copied
and encrypted so workers are launched from the encrypted image making the EBS
boot volume encrypted by default at launch time.

When the cluster is created, the config map aws-auth is deployed by default,
allowing the workers to join the masters automatically. Also, a service account
for Tiller (server-side of Helm) is created with cluster-admin permissions,
so you can deploy Charts on top of this cluster.

Lastly, some additional IAM policies are created and attached to the worker nodes
so features like cluster autoscaler or external-DNS can be implemented without
additional work from the IAM side.

## Basic usage example

```hcl
module "eks_cluster" {
  source    = "./modules/eks"

  # Network settings
  vpc_id              = "vpc-ag6bc3az93f4e5122"
  vpc_cidr            = "172.18.0.0/16"
  public_subnets_ids  = ["subnet-773cc128", "subnet-fg9c73zf"]
  private_subnets_ids = ["subnet-103fe69a", "subnet-1490799f"]

  # EKS settings
  cluster_name             = "test-eks-cluster"
  # The Kubernetes master version
  k8s_version              = "1.18"
  # The image to be used for EKS workers;
  amzn_eks_worker_ami_name = "amazon-eks-node-1.18-v20190701"

  # Find available worker AMIs from EC2 > AMI
  keypair_name          = "dev-caylent"
  boot_volume_size      = "20"
  encrypted_boot_volume = "false"

  environment           = "test"

  
  docker_encrypted_password = "test"
  cluster_log_types         = ["api","audit"]

  lt_workers_configuration = [
    {
      name                                     = "spot-node-group"
      min_size                                 = 1
      max_size                                 = 2
      override_instance_types                  = ["t3.small", "t3a.small", "t3.micro", "t3a.micro"]
      node_labels                              = "node-type=spot"
      node_taints                              = "spot=true:NoSchedule"
    },
  ]

  # Additional tags to be added to the AutoScaling Group (workers)
  tags = list(
      map("key", "App", "value", "Web", "propagate_at_launch", true),
      map("key", "Environment", "value", "development", "propagate_at_launch", true)
    )
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional_namespaces | A list of additional namespaces to create in cluster | `list(string)` | `[]` | no |
| allow_app_ports | A list of TCP ports to open in the K8S workers SG for instances/services in the VPC | `list(string)` | <pre>[<br>  "22"<br>]</pre> | no |
| amzn_eks_worker_ami_name | The name of the AMI to be used. Right now only supports Amazon Linux2 based EKS worker AMI | `any` | n/a | yes |
| asg_enabled_metrics | Listo of ASG CloudWatch metrics to be enabled | `list` | <pre>[<br>  "GroupDesiredCapacity",<br>  "GroupInServiceCapacity",<br>  "GroupInServiceInstances",<br>  "GroupMaxSize",<br>  "GroupMinSize",<br>  "GroupPendingCapacity",<br>  "GroupPendingInstances",<br>  "GroupStandbyCapacity",<br>  "GroupStandbyInstances",<br>  "GroupTerminatingCapacity",<br>  "GroupTerminatingInstances",<br>  "GroupTotalCapacity",<br>  "GroupTotalInstances"<br>]</pre> | no |
| asg_tags | A map of tags to add to the autoscaling group if using K8S autoscaler | `map(string)` | `{}` | no |
| auto_scaler_policy | True if we want to create the policy needed by cluster autoscaler | `bool` | `true` | no |
| boot_volume_size | The size of the root volume in GBs | `number` | `200` | no |
| boot_volume_type | The type of volume to allocate [gp2|io1] | `string` | `"gp2"` | no |
| charts | A map of values needed to create a new helm release | `any` | `{}` | no |
| cluster_autoscaler | Enable/disable the usage of cluster autoscaler tags and labels to use Cluster Autoscaler | `bool` | `false` | no |
| cluster_log_retention_days | Desired Kubernetes control plane logs retention days. | `string` | `""` | no |
| cluster_log_types | Desired Kubernetes control plane components that will log events to CloudWatch Logs. | `list(string)` | `[]` | no |
| cluster_name | The name of the EKS cluster | `any` | n/a | yes |
| create_environment_namespace | Create a default namespace matching the environment name | `string` | `true` | no |
| create_metrics_namespace | Create a metrics namespace for the metrics server | `string` | `true` | no |
| deploy_charts | Enables the helm charts deployment | `bool` | `false` | no |
| docker_email | The email registered in the DockerHub account | `string` | `""` | no |
| docker_encrypted_password | The KMS encrypted password (ciphertext) of the docker user | `string` | `""` | no |
| docker_registry_secret | True if we want to create a secret object to pull images from Docker Hub | `bool` | `false` | no |
| docker_secret_name | The name of the secret object to create in the k8s cluster | `string` | `"docker-registry"` | no |
| docker_secret_namespace | The namespace where to create the docker-registry secret | `string` | `"default"` | no |
| docker_server | Server location for Docker registry | `string` | `"https://index.docker.io/v1/"` | no |
| docker_username | Username for Docker registry authentication | `string` | `"docker_username"` | no |
| encrypted_boot_volume | If true, an encrypted EKS AMI will be created to support encrypted boot volumes | `any` | n/a | yes |
| endpoint_private_access | Indicates whether or not the Amazon EKS private API server endpoint is enabled | `bool` | `false` | no |
| endpoint_public_access | Indicates whether or not the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| environment | The environment name | `string` | n/a | yes |
| external_dns_cross_account_access | If true, a policy will be attached to the EKS worker role allowing the sts:AssumeRole API call | `bool` | `false` | no |
| external_dns_policy_local_access | True if we want to create the policy needed by external DNS to access a hosted zone in the same account | `bool` | `true` | no |
| iops | The amount of provisioned IOPS if volume type is io1 | `number` | `0` | no |
| k8s_version | Desired Kubernetes master version. If you do not specify a value, the latest available version is used. | `string` | `""` | no |
| keypair_name | The name of an existing key pair to access the K8S workers via SSH | `string` | `""` | no |
| lb_target_group | The App LB target groups ARNs we want this AutoScaling Group belongs to | `list(string)` | <pre>[<br>  ""<br>]</pre> | no |
| lt_workers_configuration | A list of maps defining worker group configurations to be defined using AWS Launch Templates. | `any` | `[]` | no |
| map_roles | A list of maps with the roles allowed to access EKS | <pre>list(object({<br>    role_arn = string<br>    username = string<br>    group    = string<br>  }))</pre> | `[]` | no |
| map_users | A list of maps with the IAM users allowed to access EKS | <pre>list(object({<br>    user_arn = string<br>    username = string<br>    group    = string<br>  }))</pre> | `[]` | no |
| node_groups | Map of node groups to associate to the EKS cluster | <pre>map(object({<br>    name                        = string<br>    scaling_config_desired_size = number<br>    scaling_config_max_size     = number<br>    scaling_config_min_size     = number<br>    ami_type                    = string<br>    disk_size                   = number<br>    instance_types              = list(string)<br>  }))</pre> | `{}` | no |
| private_subnets_ids | The IDs of at least two private subnets to deploy the K8S workers in | `list(string)` | n/a | yes |
| public_subnets_ids | The IDs of at least two public subnets for the K8S control plane ENIs | `list(string)` | n/a | yes |
| release_lint | Run the helm chart linter during the plan | `bool` | `false` | no |
| release_timeout | Time in seconds to wait for any individual kubernetes operation (like Jobs for hooks) | `number` | `300` | no |
| release_wait | Will wait until all resources are in a ready state before marking the release as successful. It will wait for as long as timeout | `bool` | `true` | no |
| remote_account_id | The AWS account ID where we created the cross-account role externalDNS will assume | `string` | `"111111111111"` | no |
| remote_r53_role_name | The role name created in a remote AWS account we want externalDNS to assume | `string` | `"update-route53-records"` | no |
| tags | A map of tags to add to the EKS service | `map(string)` | `{}` | no |
| vpc_cidr | The CIDR range used in the VPC | `any` | n/a | yes |
| vpc_id | The ID of the VPC where we are deploying the EKS cluster | `any` | n/a | yes |
| worker_role_additional_policies | List of IAM policies ARNs to attach to the workers role | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_ca | Shows kubernetes cluster's certificate authority |
| cluster_endpoint | Shows kubernetes master's endpoint |
| cluster_name | The name of the EKS cluster |
| cluster_oidc_endpoint | The endpoint for IRSA/OIDC |
| encrypted_ami_id | Shows kubernetes cluster's encrypted ami id |
| workers_security_group_id | Shows kubernetes cluster's security group id |
