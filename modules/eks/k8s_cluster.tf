# --------------------------------------------------------------------
# AWS EKS resources
# --------------------------------------------------------------------

## EKS cluster (K8S control plane)
resource "aws_eks_cluster" "masters" {
  name                      = var.cluster_name
  version                   = var.k8s_version
  role_arn                  = aws_iam_role.k8s_masters_role.arn
  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    #
    # The subnet IDs where ENIs will be placed for communication between masters and nodes.
    # If placed in private subnets, K8S will not be able to find public subnets for deploying
    # 'LoadBalancer' type services. These ENIs are assigned with private IPs only,
    # even when they are in public subnets.
    subnet_ids = var.public_subnets_ids

    # The security group to attach to the EKS ENIs. Only traffic between master and nodes is allowed.
    security_group_ids      = [aws_security_group.k8s_masters_sg.id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  tags = merge(
    {
      Name = var.cluster_name
    },
    var.tags,
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

## Control plane logs
resource "aws_cloudwatch_log_group" "example" {
  count             = var.cluster_log_types != "" && var.cluster_log_retention_days != "" ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
}

# --------------------------------------------------------------------
# Mixed instances workers
# --------------------------------------------------------------------

resource "aws_launch_template" "lt-workers" {
  count                  = length(var.lt_workers_configuration)
  name_prefix            = "${var.cluster_name}-${lookup(var.lt_workers_configuration[count.index], "name", "mixed")}-launch-template"
  image_id               = local.ami_id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k8s_workers_sg.id]
  user_data              = base64encode(format(local.worker_userdata["amazon"], lookup(var.lt_workers_configuration[count.index], "user_data", ""), lookup(var.lt_workers_configuration[count.index], "node_labels", ""), lookup(var.lt_workers_configuration[count.index], "node_taints", ""), lookup(var.lt_workers_configuration[count.index], "kubelet_extra_args", "")))

  iam_instance_profile {
    name = aws_iam_instance_profile.iam_workers_profile.name
  }
  block_device_mappings {
    device_name = data.aws_ami.amazon_eks_workers.root_device_name
    ebs {
      volume_type           = var.boot_volume_type
      volume_size           = var.boot_volume_size
      iops                  = var.iops
      delete_on_termination = true
    }
  }
  monitoring {
    enabled = lookup(var.lt_workers_configuration[count.index], "monitoring", false)
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "lt-workers" {
  count               = length(var.lt_workers_configuration)
  name_prefix         = "${var.cluster_name}-${lookup(var.lt_workers_configuration[count.index], "name", "mixed")}-worker"
  min_size            = lookup(var.lt_workers_configuration[count.index], "min_size", 0)
  desired_capacity    = lookup(var.lt_workers_configuration[count.index], "desired_capacity", 0)
  max_size            = lookup(var.lt_workers_configuration[count.index], "max_size", 0)
  target_group_arns   = var.lb_target_group
  vpc_zone_identifier = var.private_subnets_ids
  enabled_metrics     = var.asg_enabled_metrics

  dynamic mixed_instances_policy {
    for_each = [var.lt_workers_configuration[count.index]]
    content {
      instances_distribution {
        on_demand_base_capacity                  = lookup(var.lt_workers_configuration[count.index], "on_demand_base_capacity", 0)
        on_demand_percentage_above_base_capacity = lookup(var.lt_workers_configuration[count.index], "on_demand_percentage_above_base_capacity", 0)
        spot_instance_pools                      = lookup(var.lt_workers_configuration[count.index], "spot_instance_pools", null)
        spot_allocation_strategy                 = lookup(var.lt_workers_configuration[count.index], "spot_allocation_strategy", "capacity-optimized")
        spot_max_price                           = lookup(var.lt_workers_configuration[count.index], "spot_max_price", "")
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.lt-workers[count.index].id
          version            = "$Latest"
        }

        dynamic "override" {
          for_each = lookup(var.lt_workers_configuration[count.index], "override_instance_types", null)

          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  dynamic "tag" {
    for_each = merge(
      local.lt_asg_name_tag[count.index],
      local.asg_base_tags,
      var.cluster_autoscaler ? merge(local.cluster_autoscaler_base_tags, local.cluster_autoscaler_lt_label_tags[count.index]) : {}
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity, target_group_arns]
  }

  depends_on = [aws_eks_cluster.masters]
}

## EKS Workers: node group for K8S worker nodes
resource "aws_eks_node_group" "workers_ng" {
  for_each        = var.node_groups
  cluster_name    = aws_eks_cluster.masters.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.ng.arn
  subnet_ids      = var.public_subnets_ids
  scaling_config {
    desired_size = each.value.scaling_config_desired_size
    max_size     = each.value.scaling_config_max_size
    min_size     = each.value.scaling_config_min_size
  }
  ami_type       = each.value.ami_type
  disk_size      = each.value.disk_size
  instance_types = each.value.instance_types
  tags = {
    "Name" = "${each.value.name}"
  }
}
