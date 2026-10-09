# ── Kubernetes Namespace ─────────────────────────────────────────────────────

resource "kubernetes_namespace" "lab" {
  metadata {
    name = "lab"
    labels = {
      project = var.tags["Project"]
    }
  }
}

# ── Frontend Deployment (Nginx) ──────────────────────────────────────────────

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 80
    }
  }
}

# ── HPA for Frontend (CPU/Memory-based scaling) ──────────────────────────────

# ⚠️ HPA requires metrics-server installed in the cluster
# Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

resource "kubernetes_horizontal_pod_autoscaler" "frontend" {
  metadata {
    name      = "frontend-hpa"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.frontend.metadata[0].name
    }

    min_replicas = 2

    max_replicas = 10

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 65 # Scale when CPU > 65%
        }
      }
    }

    metric {
      type = "Resource"

      resource {
        name = "memory"

        target {
          type                = "Utilization"
          average_utilization = 75 # Scale when memory > 75%
        }
      }
    }
  }
}

# ── Backend Deployment (hashicorp/http-echo) ─────────────────────────────────

resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          image = "hashicorp/http-echo:latest"
          name  = "http-echo"

          args = ["-text", "Hello from the backend microservice!"]

          port {
            container_port = 5678
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 5678
      target_port = 5678
    }

    type = "ClusterIP"
  }
}

# ── HPA for Backend (CPU/Memory-based scaling) ──────────────────────────────

# ⚠️ HPA requires metrics-server installed in the cluster
# Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

resource "kubernetes_horizontal_pod_autoscaler" "backend" {
  metadata {
    name      = "backend-hpa"
    namespace = kubernetes_namespace.lab.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.backend.metadata[0].name
    }

    min_replicas = 2

    max_replicas = 10

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70 # Scale when CPU > 70%
        }
      }
    }

    metric {
      type = "Resource"

      resource {
        name = "memory"

        target {
          type                = "Utilization"
          average_utilization = 80 # Scale when memory > 80%
        }
      }
    }
  }
}