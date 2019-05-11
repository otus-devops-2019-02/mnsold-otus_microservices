variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}

variable zone {
  description = "Zone"

  # Значение по умолчанию
  default = "europe-west1-b"
}

variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "ubuntu-minimal-1804-lts"
}

variable private_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}

variable database_url {
  description = "Database URL"
  default     = "127.0.0.1:27017"
}

variable app_pool_nodes {
  description = "Count nodes of app"

  # Значение по умолчанию
  default = "1"
}
