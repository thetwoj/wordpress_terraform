terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.64"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 0.14.9"

  backend "s3" {
    profile = "personal"
    bucket  = "thetwoj-tfstate"
    key     = "state"
    region  = "us-east-2"
  }
}

provider "aws" {
  profile = "personal"
  region  = "us-east-2"
}

provider "aws" {
  alias   = "virginia"
  profile = "personal"
  region  = "us-east-1"
}
