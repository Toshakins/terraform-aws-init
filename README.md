# terraform-aws-init

Facilitates base for successful AWS application managed via Terraform. Includes:

* IAM user with console and API access
* S3 bucket that will be used later as a backend for Terraform
* DynamoDB to support Terraform state locking