resource "google_compute_firewall" "firewall-k8s-default" {
  name = "allow-k8s-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]
}
