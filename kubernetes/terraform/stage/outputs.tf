  #####################################################################
  # Output for K8S
  #####################################################################
  output "client_certificate" {value = "${module.k8s-cluster.client_certificate}"}
  output "client_key" {value = "${module.k8s-cluster.client_key}"}
  output "cluster_ca_certificate" {value = "${module.k8s-cluster.cluster_ca_certificate}"}
  output "host" {value = "${module.k8s-cluster.host}"}
