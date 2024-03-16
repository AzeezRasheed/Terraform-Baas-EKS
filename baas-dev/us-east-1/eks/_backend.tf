terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    region         = "us-east-1"
    bucket         = "ez-us-east-1-dev-terraform-tfstate-backend"
    key            = "eks.tfstate"
    dynamodb_table = "ez-us-east-1-dev-terraform-tfstate-backend-lock"
    profile        = "baas-dev"
    role_arn       = ""
    encrypt        = "true"
  }
}
