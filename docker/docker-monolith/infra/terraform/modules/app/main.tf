resource "google_compute_instance" "app" {
  name         = "reddit-app${count.index}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]
  count        = "${var.app_pool_nodes}"

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
  name  = "reddit-app-ip${count.index}"
  count = "${var.app_pool_nodes}"
}
