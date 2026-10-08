output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_cert" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "kubeconfig" {
  description = "Kubeconfig file content"
  value = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name     = aws_eks_cluster.this.name
    cluster_endpoint = aws_eks_cluster.this.endpoint
    cluster_ca_cert  = aws_eks_cluster.this.certificate_authority[0].data
    aws_region       = var.aws_region
  })
  sensitive = true
}

output "frontend_service_hostname" {
  description = "Hostname for the frontend service"
  value       = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].hostname
}

output "backend_service_ip" {
  description = "ClusterIP of the backend service"
  value       = kubernetes_service.backend.spec[0].cluster_ip
}