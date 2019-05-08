resource "google_compute_instance" "app" {
  name         = "reddit-app${count.index}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]
  count = "${var.app_pool_nodes}"

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.app_disk_image}"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"

    # использовать ephemeral IP для доступа из Интернет
    access_config {
      # указание IP инстанса с приложением в виде внешнего ресурса
      nat_ip = "${element(google_compute_address.app_ip.*.address, count.index)}"
    }
  }

  metadata {
    # путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

resource "google_compute_address" "app_ip" {
  #IP для инстанса с приложением в виде внешнего ресурса
  name = "reddit-app-ip${count.index}"
  count = "${var.app_pool_nodes}"
}

resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}

data "template_file" "puma_env" {
  #шаблон для создания конфигурации puma.service
  template = "${file("${path.module}/files/puma_env.tmpl.sh")}"

  vars {
    database_url = "${var.database_url}"
  }
}

resource "google_compute_firewall" "firewall_puma_http" {
  name = "allow-puma-http"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}
