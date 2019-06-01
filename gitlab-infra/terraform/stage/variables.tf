variable project {
  description = "Project ID"
}

variable region {
  description = "Region"

  # Значение по умолчанию
  default = "europe-west1"
}

variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}

variable private_key_path {
  # Описание переменной
  description = "Path to the private key used for ssh access"
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

variable app_pool_nodes {
  description = "Count nodes of app"

  # Значение по умолчанию
  default = "1"
}

variable ci_user_name {
  # Описание переменной
  description = "User name for CI"
}

variable ci_user_pass {
  # Описание переменной
  description = "User password for CI"
}

variable ci_user_group_list {
  # Описание переменной
  description = "User groups separated by commas"
}
