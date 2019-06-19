resource "google_container_cluster" "k8s_cluster" {
  name     = "${var.k8s_cluster_name}"
  #https://www.terraform.io/docs/providers/google/d/google_container_engine_versions.html
  min_master_version = "${var.min_master_version}"
  enable_legacy_abac = "false"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  initial_node_count = 1
  remove_default_node_pool = true

  addons_config {
    http_load_balancing { disabled = false }
    horizontal_pod_autoscaling { disabled = false }
    kubernetes_dashboard { disabled = false }
    network_policy_config { disabled = true }
  }

  # отключить базовую авторизацию
  master_auth {
    username = ""
    password = ""
    client_certificate_config {
      issue_client_certificate = false
    }
  }

}

resource "google_container_node_pool" "k8s_cluster_nodes" {
  name       = "${var.k8s_node_pool_name}"
  cluster    = "${google_container_cluster.k8s_cluster.name}"
  #https://www.terraform.io/docs/providers/google/d/google_container_engine_versions.html
  #version = "1.12.7-gke.6"

  node_config {
    preemptible  = true
    machine_type = "${var.machine_type}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type = "${var.disk_type}"

    metadata {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/compute",
    ]
  }

  initial_node_count = "${var.initial_node_count}"
  autoscaling {
    min_node_count = "${var.min_node_count}"
    max_node_count = "${var.max_node_count}"
  }

  management {
    auto_repair = "true"
  }

}
