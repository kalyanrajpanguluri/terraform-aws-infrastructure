terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-155335454656-ap-south-1-20261116"
    key          = "terraform/project/data-pipeline-temp.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "Terraform-AWS-Data-Pipeline"
      Environment = "Temporary"
      ManagedBy   = "Terraform"
      Owner       = "Infrastructure-Team"
    }
  }
}
