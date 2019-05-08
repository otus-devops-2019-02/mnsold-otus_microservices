output "app_external_ip" {
  value = "${module.app.app_external_ip}"
}

output "http_lb_external_ip" {
  value = "${module.app.http_lb_external_ip}"
}
