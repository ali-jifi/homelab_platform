# conn comes from PG_CONN_STR + PGPASSWORD, never put creds here
terraform {
  backend "pg" {}
}
