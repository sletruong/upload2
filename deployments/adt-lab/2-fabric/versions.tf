terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0, < 8"
    }
  }

  backend "gcs" {
    bucket = "adt-lab-gcp-tfstate"
    prefix = "adt-lab/2-fabric"
  }
}
