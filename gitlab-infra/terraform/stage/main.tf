terraform {
  # Версия terraform
  required_version = ">=0.11,<0.12"
}

provider "google" {
  # Версия провайдера
  version = "2.0.0"
  project = "${var.project}"
  region  = "${var.region}"
}

module "app" {
  source             = "../modules/app"
  public_key_path    = "${var.public_key_path}"
  zone               = "${var.zone}"
  app_disk_image     = "${var.app_disk_image}"
  private_key_path   = "${var.private_key_path}"
  app_pool_nodes     = "${var.app_pool_nodes}"
  ci_user_name       = "${var.ci_user_name}"
  ci_user_pass       = "${var.ci_user_pass}"
  ci_user_group_list = "${var.ci_user_group_list}"
}
