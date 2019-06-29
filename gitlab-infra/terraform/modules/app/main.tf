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

  connection {
    type        = "ssh"
    user        = "appuser"
    private_key = "${file(var.private_key_path)}"
  }

  #Выполнение remote-exec будет ждать, когда ВМ поднимится
  #потом можно вызавать local-exec, который не ждет когда ВМ поднимится, поэтому не выполнится
  provisioner "remote-exec" {
    inline = [
      "echo Waiting for server availability",
    ]
  }

  provisioner "local-exec" {
    command = <<EOT
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ../../ansible/playbooks/base.yml -u appuser --private-key ~/.ssh/appuser -i '${element(google_compute_address.app_ip.*.address, count.index)},'
    ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=../../ansible/roles ansible-playbook ../../ansible/playbooks/docker.yml --extra-vars "docker_edition=ce docker_package=docker-{{ docker_edition }}=18.06* docker_package_state=present docker_service_state=started docker_service_enabled=true docker_restart_handler_state:=restarted docker_install_compose=true docker_install_machine=false" -u appuser --private-key ~/.ssh/appuser -i '${element(google_compute_address.app_ip.*.address, count.index)},'
EOT
  }

  # В GCP запрещен вход по паролю, можно не выполнять
  provisioner "remote-exec" {
    inline = [
      "sudo useradd -s /bin/bash -G ${var.ci_user_group_list} -m ${var.ci_user_name}",
      "echo ${var.ci_user_name}:${var.ci_user_pass}|sudo chpasswd",
    ]
  }
}

resource "google_compute_address" "app_ip" {
  #IP для инстанса с приложением в виде внешнего ресурса
  name  = "reddit-app-ip${count.index}"
  count = "${var.app_pool_nodes}"
}
