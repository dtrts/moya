provider "aws" {
  profile = "aws"
  region  = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket = "moya-tfstate"
    key    = "02_ecs.tfstate"
    region = "eu-west-2"
  }
}
