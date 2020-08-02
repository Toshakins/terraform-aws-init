terraform {
  required_version = "~> 0.12"
  required_providers {
    aws = "3.0.0"
    template = "2.1.2"
  }
}

provider "aws" {
  # Paris
  region  = "eu-west-3"
  profile = "my_root"
}

locals {
  proj        = "terraform-aws-init"
  bucket_name = join("-", [local.proj, "bucket"])
  pgp_key     = filebase64(pathexpand(var.pgp_key_path))
}

data "aws_caller_identity" "current" {
}

data "template_file" "terraform_backend_policy" {
  template = file("terraform-s3-policy.json")
  vars = {
    bucket_name      = local.bucket_name
    admin_account_id = aws_iam_user.masteradmin.unique_id
    root_account_id  = data.aws_caller_identity.current.account_id
  }
}

resource "aws_iam_user" "masteradmin" {
  name          = "MasterAdmin"
  path          = "/system/"
  force_destroy = true
}

resource "aws_iam_access_key" "masteradmin_key" {
  user    = aws_iam_user.masteradmin.name
  pgp_key = local.pgp_key
}

resource "aws_iam_user_login_profile" "masteradmin_login_profile" {
  pgp_key = local.pgp_key
  user    = aws_iam_user.masteradmin.name
}

resource "aws_iam_group" "masteradmin_group" {
  name = "masteradmin_group"
  path = "/system/"
}

resource "aws_iam_policy" "billing_full_access" {
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "MyBillingFullAccess",
            "Effect": "Allow",
            "Action": [
                "aws-portal:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF

}

resource "aws_iam_policy" "administrator_access" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF

}

resource "aws_iam_group_policy_attachment" "admin_access_attachment" {
  group      = aws_iam_group.masteradmin_group.id
  policy_arn = aws_iam_policy.administrator_access.arn
}

resource "aws_iam_group_policy_attachment" "billing_access_attachment" {
  group      = aws_iam_group.masteradmin_group.id
  policy_arn = aws_iam_policy.billing_full_access.arn
}

resource "aws_iam_group_membership" "masteradmin_membership" {
  name  = "masteradmin_membership"
  group = aws_iam_group.masteradmin_group.id
  users = [aws_iam_user.masteradmin.id]
}

resource "aws_s3_bucket" "terraform_backend_log" {
  bucket = join("-", [local.proj, "log-bucket"])
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "terraform_backend" {
  bucket = local.bucket_name
  policy = data.template_file.terraform_backend_policy.rendered

  logging {
    target_bucket = aws_s3_bucket.terraform_backend_log.id
    target_prefix = "/log"
  }

  versioning {
    enabled = true
  }
}

resource "aws_dynamodb_table" "terraform_lock_table" {
  name           = "TerraformLockTable"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

