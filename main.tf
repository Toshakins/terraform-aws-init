# 1. Create users
# * create admin group
# * create a role that attached to a group
# https://aws.amazon.com/blogs/security/how-to-restrict-amazon-s3-bucket-access-to-a-specific-iam-role/
# 2. DynamoDB for locking

terraform {
  required_version = "~> 0.11"
}

provider "aws" {
  # Paris
  region = "eu-west-3"
  profile = "my"
}

locals {
  proj = "terraform-aws-init"
  bucket_name = "${join("-", list(local.proj, "bucket"))}"
  pgp_key = "${base64encode(file(pathexpand(var.pgp_key_path)))}"
}

data "aws_caller_identity" "current" {}

data "template_file" "terraform_backend_policy" {
  template = "${file("terraform-s3-policy.json")}"
  vars {
    bucket_name = "${local.bucket_name}"
    group_id = "${aws_iam_group.masteradmin_group.id}"
    account_id = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_user" "masteradmin" {
  name = "MasterAdmin"
  path = "/system/"
}

resource "aws_iam_access_key" "masteradmin_key" {
  user = "${aws_iam_user.masteradmin.name}"
  pgp_key = "${local.pgp_key}"
}

resource "aws_iam_user_login_profile" "masteradmin_login_profile" {
  pgp_key = "${local.pgp_key}"
  user = "${aws_iam_user.masteradmin.name}"
}

resource "aws_iam_group" "masteradmin_group" {
  name = "masteradmin_group"
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
  group = "${aws_iam_group.masteradmin_group.id}"
  policy_arn = "${aws_iam_policy.administrator_access.arn}"
}

resource "aws_iam_group_policy_attachment" "billing_access_attachment" {
  group = "${aws_iam_group.masteradmin_group.id}"
  policy_arn = "${aws_iam_policy.billing_full_access.arn}"
}

resource "aws_iam_group_membership" "masteradmin_membership" {
  name = "masteradmin_membership"
  group = "${aws_iam_group.masteradmin_group.id}"
  users = ["${aws_iam_user.masteradmin.id}"]
}

resource "aws_s3_bucket" "terraform_backend_log" {
  bucket = "${join("-", list(local.proj, "log-bucket"))}"
  acl = "log-delivery-write"
}

resource "aws_s3_bucket" "terraform_backend" {
  bucket = "${local.bucket_name}"
  policy = "${data.template_file.terraform_backend_policy.rendered}"

  logging {
    target_bucket = "${aws_s3_bucket.terraform_backend_log.id}"
    target_prefix = "/log"
  }

  versioning {
    enabled = true
  }
}