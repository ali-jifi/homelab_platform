# source this, don't run it: `source scripts/tf-env.sh`
# sets the postgres backend conn for tf from the sops encrypted secrets file
_secrets="$(git rev-parse --show-toplevel)/infra/terraform/secrets.sops.yaml"
export PG_CONN_STR="postgres://terraform@192.168.0.210/terraform?sslmode=require"
PGPASSWORD="$(sops decrypt --extract '["pg_password"]' "$_secrets")" && export PGPASSWORD
unset _secrets
