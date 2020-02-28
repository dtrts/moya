provider "aws" {
  profile = "aws"
  region  = "eu-west-2"
}
terraform {
  backend "s3" {
    bucket = "moya-tfstate"
    key    = "00_vpc.tfstate"
    region = "eu-west-2"
  }
}

resource "aws_vpc" "moya" {
  cidr_block = "10.66.92.0/24"
  tags = {
    Name = "moya"
  }
}

resource "aws_subnet" "moya-subnets-euwa" {
  for_each = {
    moya-0 = "10.66.92.0/27"
    moya-1 = "10.66.92.32/27"
  }
  vpc_id            = aws_vpc.moya.id
  availability_zone = "eu-west-2a"
  cidr_block        = each.value
  tags = {
    Name = each.key
  }
}

resource "aws_subnet" "moya-subnets-euwab" {
  for_each = {
    moya-2 = "10.66.92.64/27"
    moya-3 = "10.66.92.96/27"
  }
  vpc_id            = aws_vpc.moya.id
  availability_zone = "eu-west-2b"
  cidr_block        = each.value
  tags = {
    Name = each.key
  }
}

resource "aws_subnet" "moya-subnets-euwc" {
  for_each = {
    moya-4 = "10.66.92.128/27"
    moya-5 = "10.66.92.160/27"
  }
  vpc_id            = aws_vpc.moya.id
  availability_zone = "eu-west-2c"
  cidr_block        = each.value
  tags = {
    Name = each.key
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.moya.id
}


output "vpc" {
  value = aws_vpc.moya
}
