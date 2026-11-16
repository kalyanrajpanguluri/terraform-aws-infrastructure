module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  enable_nat_gateway  = var.enable_nat_gateway
}

module "security_groups" {
  source = "./modules/security-groups"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "s3" {
  source = "./modules/s3"

  bucket_name  = var.app_bucket_name
  project_name = var.project_name
}

module "github_oidc" {
  source = "./modules/iam"

  github_owner         = "kalyanrajpanguluri"
  github_owner_id      = "312638238"
  github_repository    = "terraform-aws-infrastructure"
  github_repository_id = "1460425852"
  github_branch        = "main"

  state_bucket_name = "terraform-state-155335454656-ap-south-1-20261116"
  state_key         = "terraform/project/terraform.tfstate"
  app_bucket_name   = var.app_bucket_name

  role_name = "terraform-github-actions-plan"
}
