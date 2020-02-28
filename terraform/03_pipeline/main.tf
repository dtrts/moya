provider "aws" {
  profile = "aws"
  region  = "eu-west-2"
}
terraform {
  backend "s3" {
    bucket = "moya-tfstate"
    key    = "03_pipeline.tfstate"
    region = "eu-west-2"
  }
}


variable "app" {
  default = "moya"
}

variable "environment" {
  default = "poc"
}

variable "region" {
  default = "eu-west-2"
}


data "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

variable "subnets" {
  default = ["subnet-0e4ff2bbc29485dac", "subnet-05ba0b9e6fe80d483"]
}

data "aws_caller_identity" "current" {}


data "aws_iam_policy_document" "build-pipeline-kms-key-policy-document" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "Allow access for Key Administrators"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dcms/dcms-Administrator"]
    }
  }
  statement {
    sid = "Allow use of the key"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dcms/dcms-Administrator",
        "${aws_iam_role.codepipeline-iam-role.arn}",
        "${aws_iam_role.codebuild-iam-role.arn}"
      ]
    }
  }
  statement {
    sid = "Allow attachment of persistent resources"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dcms/dcms-Administrator",
        "${aws_iam_role.codepipeline-iam-role.arn}",
        "${aws_iam_role.codebuild-iam-role.arn}"
      ]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}


resource "aws_kms_key" "build-pipeline-kms-key" {
  description         = "KMS Key used to encrypt the S3 buckets used by the build pipeline"
  key_usage           = "ENCRYPT_DECRYPT"
  policy              = data.aws_iam_policy_document.build-pipeline-kms-key-policy-document.json
  enable_key_rotation = true
  is_enabled          = true

}

resource "aws_kms_alias" "build-pipeline-kms-key-alias" {
  name          = "alias/${data.aws_vpc.main.tags.Name}-build-pipeline-kms-key"
  target_key_id = aws_kms_key.build-pipeline-kms-key.key_id
}

resource "aws_s3_bucket" "codebuild-s3-bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.app}-${var.environment}-codebuild-s3-bucket"
  acl    = "private"
  region = var.region

  force_destroy = true
}


data "aws_iam_policy_document" "codebuild-iam-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild-iam-policy-document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.codebuild-s3-bucket.arn}",
      "${aws_s3_bucket.codebuild-s3-bucket.arn}/*"
    ]
  }
  statement {
    actions = [
      "ec2:CreateNetworkInterfacePermission"
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"

      values = var.subnets [
        "${var.subnets[0]}",
        "${var.subnets[1]}"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"

      values = [
        "codebuild.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "codebuild-iam-policy" {
  name   = "codebuild-iam-policy"
  policy = data.aws_iam_policy_document.codebuild-iam-policy-document.json
}

resource "aws_iam_role" "codebuild-iam-role" {
  name               = "codebuild-iam-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild-iam-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "codebuild-iam-policy-attach" {
  role       = aws_iam_role.codebuild-iam-role.name
  policy_arn = aws_iam_policy.codebuild-iam-policy.arn
}

resource "aws_security_group" "codebuild" {
  name        = "${data.aws_vpc.main.tags.Name}-${var.environment}-sg-codebuild"
  description = "Security Group for CodeBuild"
  vpc_id      = data.aws_vpc.main.id
}
resource "aws_security_group_rule" "codebuild-all-egress" {
  description       = "All Egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.codebuild.id
}

resource "aws_codebuild_project" "codebuild-lambda-code" {
  name          = "codebuild-lambda-code"
  description   = "codebuild-lambda-code"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild-iam-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild-s3-bucket.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-group"
      stream_name = "codebuild-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild-s3-bucket.bucket}/build-log"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  vpc_config {
    vpc_id = data.aws_vpc.main.id

    subnets = [
      "${tolist(data.aws_subnet_ids.private.ids)[0]}",
      "${tolist(data.aws_subnet_ids.private.ids)[1]}"
    ]

    security_group_ids = [
      aws_security_group.codebuild.id
    ]
  }
}

resource "aws_s3_bucket" "codepipeline-s3-bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.app}-${var.environment}-codepipeline-s3-bucket"
  acl    = "private"
  region = var.region

  force_destroy = true
}

data "aws_iam_policy_document" "codepipeline-iam-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline-iam-policy-document" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.codepipeline-s3-bucket.arn}",
      "${aws_s3_bucket.codepipeline-s3-bucket.arn}/*"
    ]
  }
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = ["arn:aws:codestar-connections:eu-west-1:878872391919:connection/e12783e8-bec9-4fb3-bc77-e0d96b1c9a95"]
  }
  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codepipeline-iam-policy" {
  name   = "codepipeline-iam-policy"
  policy = data.aws_iam_policy_document.codepipeline-iam-policy-document.json
}

resource "aws_iam_role" "codepipeline-iam-role" {
  name               = "codepipeline-iam-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline-iam-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "codepipeline-iam-policy-attach" {
  role       = aws_iam_role.codepipeline-iam-role.name
  policy_arn = aws_iam_policy.codepipeline-iam-policy.arn
}

resource "aws_codepipeline" "codepipeline-lambda-code" {
  name     = "codepipeline-lambda-code"
  role_arn = aws_iam_role.codepipeline-iam-role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline-s3-bucket.bucket
    type     = "S3"
  }


  # https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html#w531aac44c19c25b3b1
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:eu-west-1:878872391919:connection/e12783e8-bec9-4fb3-bc77-e0d96b1c9a95"
        FullRepositoryId = "rockar_team/used-car-ingestion"
        BranchName       = "master"
        OutputArtifactFormat : "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild-lambda-code.name
      }
    }
  }
}
