data "google_client_openid_userinfo" "me" {}

output "terraform_active_identity" {
  value = data.google_client_openid_userinfo.me.email
}