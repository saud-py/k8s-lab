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