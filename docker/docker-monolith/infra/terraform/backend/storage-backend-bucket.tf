provider "google" {
  version = "2.0.0"
  project = "${var.project}"
  region  = "${var.region}"
}

# предварительное создание бакета для хранения состоянитя терраформ
module "terraform-remote-state" {
  source  = "SweetOps/storage-bucket/google"
  version = "0.1.1"

  # Имена поменяйте на другие
  name = ["docker-otus-mnsold-terraform-remote-state"]
}

output terraform-remote-state_url {
  value = "${module.terraform-remote-state.url}"
}
