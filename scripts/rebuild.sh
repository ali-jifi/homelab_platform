#!/usr/bin/env bash
# tears the cluster down and rebuilds it from zero, timing every stage into timings/rebuild.csv
# "zero" = no VMs, no k8s. assumed to already exist: the anchor CT (tf state) and your age key
#
# usage: scripts/rebuild.sh warm|cold
#   warm = keep the debian image on proxmox
#   cold = delete the image first so it gets downloaded again (uses root ssh to the host, the tf token can't delete files)
set -euo pipefail

MODE="${1:-}"
[[ "$MODE" == warm || "$MODE" == cold ]] || { echo "usage: $0 warm|cold" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel)"
TF="$ROOT/infra/terraform"
CSV="$ROOT/timings/rebuild.csv"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
PVE_HOST=ajserver2
AGE_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
export KUBECONFIG="$HOME/.kube/homelab.yaml"
cd "$ROOT"

# chart + version come from the argo app files so the bootstrap install == what argo takes over
chart_field() { sed -nE "s/^[[:space:]-]*$2:[[:space:]]*//p" "platform/apps/$1.yaml" | head -1; }

stage() {
  local name=$1 start=$SECONDS
  shift
  echo "==> $name"
  "$@"
  local secs=$((SECONDS - start))
  echo "$RUN_ID,$MODE,$name,$secs" >> "$CSV"
  echo "    $name took ${secs}s"
}

preflight() {
  for t in terraform kubectl helm sops ssh curl jq; do
    command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; return 1; }
  done
  [[ -f "$AGE_KEY" ]] || { echo "no age key at $AGE_KEY, every encrypted secret in the repo is unreadable without it" >&2; return 1; }
  sops decrypt infra/terraform/secrets.sops.yaml >/dev/null
  # shellcheck source=/dev/null
  source scripts/tf-env.sh
  terraform -chdir="$TF" init -input=false >/dev/null
}

destroy_vms() {
  # targeting the VMs also takes out the k3s installs that depend on them, the image + token stay
  terraform -chdir="$TF" destroy -auto-approve -input=false -target=proxmox_virtual_environment_vm.node
}

tailscale_cleanup() {
  # old cluster's operator + proxies are still registered, without this the new ones come back as argocd-1, grafana-1 etc
  local creds id secret token
  creds=$(sops decrypt platform/tailscale/operator-oauth.sops.yaml)
  id=$(awk '/client_id:/{print $2}' <<<"$creds")
  secret=$(awk '/client_secret:/{print $2}' <<<"$creds")
  token=$(curl -sf -d "client_id=$id" -d "client_secret=$secret" https://api.tailscale.com/api/v2/oauth/token | jq -r .access_token)
  curl -sf -H "Authorization: Bearer $token" https://api.tailscale.com/api/v2/tailnet/-/devices \
    | jq -r '.devices[] | select((.tags // []) | any(. == "tag:k8s" or . == "tag:k8s-operator")) | "\(.id) \(.hostname)"' \
    | while read -r dev host; do
        echo "    removing tailnet device $host"
        curl -sf -o /dev/null -X DELETE -H "Authorization: Bearer $token" "https://api.tailscale.com/api/v2/device/$dev"
      done
}

delete_image() {
  local volid
  volid=$(terraform -chdir="$TF" state show -no-color proxmox_download_file.debian 2>/dev/null | awk -F'"' '/^ *id *=/{print $2}')
  if [[ -n "$volid" ]]; then
    ssh "root@$PVE_HOST" pvesm free "$volid"
  else
    echo "    no image in state, nothing to delete"
  fi
}

image() { terraform -chdir="$TF" apply -auto-approve -input=false -target=proxmox_download_file.debian; }
vms_and_k3s() { terraform -chdir="$TF" apply -auto-approve -input=false; }
kubeconfig() { bash scripts/get-kubeconfig.sh "$KUBECONFIG"; }

cilium() {
  helm upgrade --install cilium "$(chart_field cilium chart)" \
    --repo "$(chart_field cilium repoURL)" --version "$(chart_field cilium targetRevision)" \
    --namespace kube-system -f platform/cilium/values.yaml --wait --timeout 10m
  kubectl wait --for=condition=Ready nodes --all --timeout=10m
}

argocd() {
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  # the only secret not stored in git
  kubectl -n argocd create secret generic sops-age --from-file=keys.txt="$AGE_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
  sops decrypt bootstrap/repo-homelab.sops.yaml | kubectl apply -f -
  helm upgrade --install argocd "$(chart_field argocd chart)" \
    --repo "$(chart_field argocd repoURL)" --version "$(chart_field argocd targetRevision)" \
    --namespace argocd -f platform/argocd/values.yaml --wait --timeout 10m
  kubectl apply -f bootstrap/root-app.yaml
}

apps_healthy() {
  # root + one app per file in platform/apps, all Synced + Healthy
  local want=$(( $(ls platform/apps/*.yaml | wc -l) + 1 )) deadline=$((SECONDS + 1200)) ok
  while (( SECONDS < deadline )); do
    ok=$(kubectl -n argocd get applications -o json 2>/dev/null \
      | jq '[.items[] | select(.status.sync.status == "Synced" and .status.health.status == "Healthy")] | length')
    echo "    $ok/$want apps synced + healthy"
    (( ok == want )) && return 0
    sleep 15
  done
  kubectl -n argocd get applications
  return 1
}

mkdir -p "$(dirname "$CSV")"
[[ -f "$CSV" ]] || echo "run_id,mode,stage,seconds" > "$CSV"

echo "rebuild $RUN_ID ($MODE): this DESTROYS cp-1 and wk-1 and everything on them"
read -rp "type the word rebuild to continue: " answer
[[ "$answer" == rebuild ]] || { echo "aborted"; exit 1; }

total_start=$SECONDS
stage preflight preflight
stage destroy destroy_vms
stage tailscale_cleanup tailscale_cleanup
[[ "$MODE" == cold ]] && stage delete_image delete_image
stage image image
stage vms_and_k3s vms_and_k3s
stage kubeconfig kubeconfig
stage cilium cilium
stage argocd argocd
stage apps_healthy apps_healthy
echo "$RUN_ID,$MODE,total,$((SECONDS - total_start))" >> "$CSV"
echo "done in $((SECONDS - total_start))s, timings in $CSV"
