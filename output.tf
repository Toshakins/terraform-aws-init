output "access_key_secret" {
  value = "${aws_iam_access_key.masteradmin_key.encrypted_secret}"
}

output "login_secret" {
  value = "${aws_iam_user_login_profile.masteradmin_login_profile.encrypted_password}"
}

output "user" {
  value = "${aws_iam_user.masteradmin.arn}"
}