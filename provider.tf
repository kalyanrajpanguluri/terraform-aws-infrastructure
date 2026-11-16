provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "Terraform-AWS-Infrastructure"
      Environment = "Dev"
      ManagedBy   = "Terraform"
      Owner       = "Infrastructure-Team"
    }
  }
}
