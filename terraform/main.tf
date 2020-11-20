terraform {
  required_version = ">= 0.13.0"

  backend "gcs" {
    bucket = "civic-gate-295923-terraform"
    prefix = "/state/storybooks"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 2.0"
    }

    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = ">= 0.6"
    }
  }
}
