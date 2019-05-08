terraform {
  backend "gcs" {
    bucket = "docker-otus-mnsold-terraform-remote-state"
    prefix = "stage"
  }
}
