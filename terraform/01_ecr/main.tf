provider "aws" {
  profile = "aws"
  region  = "eu-west-2"
}
terraform {
  backend "s3" {
    bucket = "moya-tfstate"
    key    = "01_ecr.tfstate"
    region = "eu-west-2"
  }
}

resource "aws_ecr_repository" "moya_hanger" {
  name                 = "moya_hanger"
  image_tag_mutability = "MUTABLE"
}
