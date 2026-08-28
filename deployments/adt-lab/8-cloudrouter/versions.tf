terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8"
    }
  }

  backend "gcs" {
    bucket = "adt-lab-gcp-tfstate"
    prefix = "adt-lab/8-cloudrouter"
  }
}

provider "google" {
  project = "rteller-demo-svc-e265-aaac"
}
