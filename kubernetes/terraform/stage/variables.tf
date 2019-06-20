variable project {
  description = "Project ID"
}

variable region {
  description = "Region"
}

variable zone {
  description = "Zone"
}

variable k8s_cluster_name {
  description = "Kubernetes cluster name"
}

variable min_master_version {
  description = "Kubernetes version"
}

variable k8s_node_pool_name {
  description = "Kubernetes node pool name"
}

variable machine_type {
  description = "Node machine type"
}

variable disk_size_gb {
  description = "Node disk size in GB"
}

variable disk_type {
  description = "Node disk type"
}

variable initial_node_count {
  description = "Initial count nodes"
}

variable min_node_count {
  description = "Min count of autoscale nodes"
}

variable max_node_count {
  description = "Max count of autoscale nodes"
}
