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
    selector = kubernetes_deployment.frontend.spec[0].template[0].metadata[0].labels[0]
    port     = 80

    type = "LoadBalancer"

    # Expose via NodePort if no LoadBalancer is available (optional, can be removed)
    port {
      port        = 80
      target_port = 80
    }

    # Optionally add load balancer ingress
    load_balancer_ingress {
      # In a real environment you might specify IPs here, but we leave it blank for auto-allocation
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
    selector = kubernetes_deployment.backend.spec[0].template[0].metadata[0].labels[0]
    port     = 5678

    type = "ClusterIP"
  }
}