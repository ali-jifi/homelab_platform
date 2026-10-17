# Connection comes from PG_CONN_STR and PGPASSWORD; never put credentials here.
terraform {
  backend "pg" {}
}
