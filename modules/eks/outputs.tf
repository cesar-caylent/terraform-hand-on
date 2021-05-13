# -------------------------------------------------------------
# Settings exported by the module (outputs)
# -------------------------------------------------------------

output "cluster_endpoint" {
  description = "Shows kubernetes master's endpoint"
  value       = aws_eks_cluster.masters.endpoint
}

output "cluster_ca" {
  description = "Shows kubernetes cluster's certificate authority"
  value       = aws_eks_cluster.masters.certificate_authority
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.masters.name
}

output "workers_security_group_id" {
  description = "Shows kubernetes cluster's security group id"
  value       = aws_security_group.k8s_workers_sg.id
}

output "encrypted_ami_id" {
  description = "Shows kubernetes cluster's encrypted ami id"
  value       = join("", aws_ami_copy.encrypted_eks_ami.*.id)
}

output "cluster_oidc_endpoint" {
  description = "The endpoint for IRSA/OIDC"
  value       = aws_eks_cluster.masters.identity[0].oidc[0].issuer
}

