# --------------------------------------------------------------------
# kubeconfig file
# --------------------------------------------------------------------

## generate a template for the kubeconfig file
data "template_file" "kubeconfig" {
  template = file("${path.module}/templates/kubeconfig.yaml.tpl")

  vars = {
    cluster_name     = var.cluster_name
    cluster_endpoint = aws_eks_cluster.masters.endpoint
    cluster_cert     = aws_eks_cluster.masters.certificate_authority[0].data
  }
}

## generate a local file from the rendered template, to be used by TF to deploy kube objects
resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "./.kube/config_${var.cluster_name}"
}

# --------------------------------------------------------------------
# aws-auth ConfigMap
# --------------------------------------------------------------------

## generate base template for workers
data "template_file" "worker_role_arns" {
  template = file("${path.module}/templates/worker-role.tpl")

  vars = {
    workers_role_arn = aws_iam_role.k8s_workers_role.arn
  }
}

## generate base template for workers in node groups
data "template_file" "node_group_worker_role_arns" {
  template = file("${path.module}/templates/node-group-worker-role.tpl")

  vars = {
    node_group_workers_role_arn = aws_iam_role.ng.arn
  }
}

## generate templates mapping IAM users with cluster entities (users/groups)
data "template_file" "map_users" {
  count    = length(var.map_users)
  template = file("${path.module}/templates/aws-auth_map-users.yaml.tpl")

  vars = {
    user_arn = var.map_users[count.index]["user_arn"]
    username = var.map_users[count.index]["username"]
    group    = var.map_users[count.index]["group"]
  }
}

## generate templates mapping IAM roles with cluster entities (users/groups)
data "template_file" "map_roles" {
  count    = length(var.map_roles)
  template = file("${path.module}/templates/aws-auth_map-roles.yaml.tpl")

  vars = {
    role_arn = var.map_roles[count.index]["role_arn"]
    username = var.map_roles[count.index]["username"]
    group    = var.map_roles[count.index]["group"]
  }
}

## deploy the aws-auth ConfigMap
resource "kubernetes_config_map" "aws_auth_cm" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = join(
      "",
      data.template_file.map_roles.*.rendered,
      data.template_file.worker_role_arns.*.rendered,
      data.template_file.node_group_worker_role_arns.*.rendered,
    )
    mapUsers = join("", data.template_file.map_users.*.rendered)
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
  ]
}

# --------------------------------------------------------------------
# RBAC custom roles
# --------------------------------------------------------------------

## ClusterRole allowing read-only access to some kube objects
resource "kubernetes_cluster_role" "ro_cluster_role" {
  metadata {
    name = "read-only"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "pods", "pods/log", "pods/status", "configmaps", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["daemonsets", "deployments"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["daemonsets", "deployments", "ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

## Bind the ClusterRole 'read-only' to a group named 'ReadOnlyGroup'
resource "kubernetes_cluster_role_binding" "ro_role_binding" {
  metadata {
    name = "read-only-global"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "read-only"
  }

  subject {
    kind      = "Group"
    name      = "ReadOnlyGroup"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    kubernetes_cluster_role.ro_cluster_role,
    kubernetes_config_map.aws_auth_cm,
  ]
}

## Bind the ClusterRole 'edit' to a group named 'PowerUserGroup'
resource "kubernetes_cluster_role_binding" "power_user" {
  metadata {
    name = "power-user-global"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "Group"
    name      = "PowerUserGroup"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

# --------------------------------------------------------------------
# Namespace
# --------------------------------------------------------------------
resource "kubernetes_namespace" "environment" {
  count = var.create_environment_namespace ? 1 : 0

  metadata {
    name = var.environment

    labels = {
      name = var.environment
    }
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

resource "kubernetes_namespace" "metrics" {
  count = var.create_metrics_namespace ? 1 : 0

  metadata {
    name = "metrics"

    labels = {
      name = "metrics"
    }
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

resource "kubernetes_namespace" "additional" {
  count = length(var.additional_namespaces)

  metadata {
    name = var.additional_namespaces[count.index]

    labels = {
      name = var.additional_namespaces[count.index]
    }
  }

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

# --------------------------------------------------------------------
# Secret for Docker Registry
# --------------------------------------------------------------------

## data source for decrypting the Docker Registry password (encrypted with KMS)
data "aws_kms_secrets" "docker_password" {
  count = var.docker_registry_secret ? 1 : 0

  secret {
    name    = "docker_password"
    payload = var.docker_encrypted_password
  }
}

resource "kubernetes_secret" "docker_registry_secret" {
  count = var.docker_registry_secret ? 1 : 0

  metadata {
    name      = var.docker_secret_name
    namespace = var.docker_secret_namespace
  }

  data = {
    ".dockercfg" = jsonencode(local.docker_config)
  }

  type = "kubernetes.io/dockercfg"

  depends_on = [
    aws_eks_cluster.masters,
    aws_autoscaling_group.lt-workers,
    kubernetes_config_map.aws_auth_cm,
  ]
}

