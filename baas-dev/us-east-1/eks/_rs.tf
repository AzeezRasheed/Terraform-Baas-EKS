data "terraform_remote_state" "baas_dev_vpc_us" {
  backend = "s3"
  config = {
    bucket  = "ez-us-east-1-dev-terraform-tfstate-backend"
    key     = "vpc.tfstate"
    profile = "baas-dev"
    region  = "us-east-1"
  }
}

data "terraform_remote_state" "baas_shared_vpn" {
  backend = "s3"
  config = {
    bucket  = "ez-us-east-1-shared-terraform-tfstate-backend"
    key     = "ec2-client-vpn-full-tunnel.tfstate"
    profile = "baas-shared"
    region  = "us-east-1"
  }
}

data "terraform_remote_state" "baas_shared_vpc_us" {
  backend = "s3"
  config = {
    bucket  = "ez-us-east-1-shared-terraform-tfstate-backend"
    key     = "vpc.tfstate"
    profile = "baas-shared"
    region  = "us-east-1"
  }
}

data "terraform_remote_state" "baas_shared_tgw_us" {
  backend = "s3"
  config = {
    bucket  = "ez-us-east-1-shared-terraform-tfstate-backend"
    key     = "tgw.tfstate"
    profile = "baas-shared"
    region  = "us-east-1"
  }
}
