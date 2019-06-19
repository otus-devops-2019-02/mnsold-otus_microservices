terraform {
  # Версия terraform
  required_version = ">=0.11,<0.12"
}

provider "google" {
  # Версия провайдера
  version = "2.0.0"
  project = "${var.project}"
  region  = "${var.region}"
  zone = "${var.zone}"
}

module "k8s-cluster" {
  source             = "../modules/k8s-cluster"

  #kubernetes cluster
  k8s_cluster_name = "${var.k8s_cluster_name}"
  min_master_version = "${var.min_master_version}"

  #kubernetes nodes pool
  k8s_node_pool_name = "${var.k8s_node_pool_name}"
  machine_type = "${var.machine_type}"
  disk_size_gb = "${var.disk_size_gb}"
  disk_type = "${var.disk_type}"
  initial_node_count = "${var.initial_node_count}"
  min_node_count = "${var.min_node_count}"
  max_node_count = "${var.max_node_count}"
}
