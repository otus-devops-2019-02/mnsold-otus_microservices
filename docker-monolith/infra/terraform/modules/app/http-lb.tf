# HTTP балансировщик
resource "google_compute_target_pool" "reddit_app_pool" {
  name = "reddit-app-pool"

  instances = [
    "${google_compute_instance.app.*.self_link}",
  ]

  health_checks = [
    "${google_compute_http_health_check.reddit_app_pool_healthcheck.name}",
  ]
}

resource "google_compute_http_health_check" "reddit_app_pool_healthcheck" {
  name               = "reddit-app-pool-healthcheck"
  request_path       = "/"
  check_interval_sec = 5
  timeout_sec        = 5
  port               = 9292
}

resource "google_compute_address" "http_lb_ip" {
  #Статический IP
  name = "http-lb-ip"
}

resource "google_compute_forwarding_rule" "reddit_app_lb_rule" {
  name       = "reddit-app-lb-rule"
  target     = "${google_compute_target_pool.reddit_app_pool.self_link}"
  port_range = "9292"
  ip_address = "${google_compute_address.http_lb_ip.self_link}"
}
