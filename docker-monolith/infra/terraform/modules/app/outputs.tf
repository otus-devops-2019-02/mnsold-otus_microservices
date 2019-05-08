output "app_external_ip" {
  value = "${google_compute_instance.app.*.network_interface.0.access_config.0.nat_ip}"
}

output "http_lb_external_ip" {
  value = "${google_compute_address.http_lb_ip.address}"
}
