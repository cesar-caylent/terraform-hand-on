# --------------------------------------------------------------------
# Security Groups settings for EKS (masters & workers)
# --------------------------------------------------------------------

## Security Group for ENI created for the K8S Control Plane
resource "aws_security_group" "k8s_masters_sg" {
  name   = "${var.cluster_name}-masters-sg"
  vpc_id = var.vpc_id
  tags = {
    "Name" = "${var.cluster_name}_masters_sg"
  }
}

## Control Plane SG rule: Allow outbound traffic from K8S masters
resource "aws_security_group_rule" "outbound_traffic_masters_sg" {
  type              = "egress"
  protocol          = -1
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_masters_sg.id
}

## Control Plane SG rule: Allow inbound traffic to the K8S API from K8S workers SG
resource "aws_security_group_rule" "workers_inbound_443_traffic_masters_sg" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = aws_security_group.k8s_workers_sg.id
  security_group_id        = aws_security_group.k8s_masters_sg.id
}

## Security Group for K8S Workers
resource "aws_security_group" "k8s_workers_sg" {
  name   = "${var.cluster_name}-workers-sg"
  vpc_id = var.vpc_id
  tags = {
    "Name" = "${var.cluster_name}_workers_sg"
  }
}

## K8S workers SG rule: Allow outbound traffic from K8S nodes
resource "aws_security_group_rule" "outbound_traffic_workers_sg" {
  type              = "egress"
  protocol          = -1
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_workers_sg.id
}

##  K8S workers SG rule: Allow communication between K8s nodes
resource "aws_security_group_rule" "self_traffic_workers_sg" {
  type              = "ingress"
  protocol          = -1
  from_port         = 0
  to_port           = 65535
  self              = true
  security_group_id = aws_security_group.k8s_workers_sg.id
}

##  K8S workers SG rule: Allow inbound traffic from the K8S API
resource "aws_security_group_rule" "masters_inbound_traffic_workers_sg" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 1024
  to_port                  = 65535
  source_security_group_id = aws_security_group.k8s_masters_sg.id
  security_group_id        = aws_security_group.k8s_workers_sg.id
}

##  K8S workers SG rule: Allow inbound traffic to specific App ports from instances the VPC
resource "aws_security_group_rule" "app_inbound_traffic_workers_sg" {
  count             = length(var.allow_app_ports)
  type              = "ingress"
  protocol          = "tcp"
  from_port         = element(var.allow_app_ports, count.index)
  to_port           = element(var.allow_app_ports, count.index)
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.k8s_workers_sg.id
}

