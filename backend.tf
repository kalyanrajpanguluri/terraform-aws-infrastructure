terraform {
  backend "s3" {
    bucket       = "terraform-state-155335454656-ap-south-1-20261116"
    key          = "terraform/project/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
