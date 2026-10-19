# Source this (don't execute it): `source scripts/tf-env.sh`
# Sets the Postgres backend connection for Terraform from the SOPS-encrypted secrets file.
_secrets="$(git rev-parse --show-toplevel)/infra/terraform/secrets.sops.yaml"
export PG_CONN_STR="postgres://terraform@192.168.0.210/terraform?sslmode=require"
PGPASSWORD="$(sops decrypt --extract '["pg_password"]' "$_secrets")" && export PGPASSWORD
unset _secrets
