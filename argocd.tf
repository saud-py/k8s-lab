# ── Argo CD Namespace ────────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      app = "argocd"
    }
  }
}

# ── Argo CD Helm Release ─────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.2" # Check https://github.com/argoproj/argo-helm/releases for latest
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Wait for deployment to be ready (timeout in seconds)
  timeout       = 600
  wait_for_jobs = true

  # Values for production-ready, cost-optimized setup
  set = [
    {
      name  = "global.domain"
      value = "argocd.${var.cluster_name}.example.com" # Replace with your domain
    },
    {
      name  = "server.service.type"
      value = "LoadBalancer" # Exposes Argo CD UI via AWS NLB
    },
    {
      name  = "server.ingress.enabled"
      value = "false" # We'll use LoadBalancer instead for simplicity
    },
    {
      name  = "applicationSet.enabled"
      value = "false"
    },
    {
      name  = "notifications.enabled"
      value = "false"
    },
    {
      name  = "dex.enabled"
      value = "false" # Disable Dex if not using SSO
    },
    {
      name  = "server.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "server.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "server.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "server.resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "repoServer.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "repoServer.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "repoServer.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "repoServer.resources.requests.memory"
      value = "128Mi"
    }
  ]

  # Admin password - CHANGE THIS! Use a secret in production
  # Initial admin password is auto-generated; retrieve with:
  # kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  set_sensitive = [
    {
      name  = "configs.params.server.insecure"
      value = "true" # For dev only; use TLS in production
    }
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ── Optional: Argo CD Application for Your Microservices ─────────────────────

# This creates an Argo CD Application that points to your Git repo
# Uncomment and configure after Argo CD is running

# resource "kubernetes_manifest" "argocd_application" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "microservices-lab"
#       namespace = kubernetes_namespace.argocd.metadata[0].name
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = "https://github.com/YOUR_ORG/YOUR_REPO.git"
#         targetRevision = "main"
#         path           = "."  # Path to your Kubernetes manifests (or helm chart)
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "lab"
#       }
#       syncPolicy = {
#         automated = {
#           prune    = true
#           selfHeal = true
#         }
#         syncOptions = ["CreateNamespace=true"]
#       }
#     }
#   }
#
#   depends_on = [helm_release.argocd]
# }

# ── Output Argo CD Access Info ───────────────────────────────────────────────

output "argocd_server_hostname" {
  description = "Argo CD server LoadBalancer hostname"
  value       = data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname
}

# Get the Argo CD server service (created by Helm)
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd]
}