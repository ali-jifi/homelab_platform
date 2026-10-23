#!/usr/bin/env bash
# grabs the k3s admin kubeconfig from cp-1 and points it at the node IP instead of 127.0.0.1
set -euo pipefail
umask 077

CP=192.168.0.201
OUT="${1:-$HOME/.kube/homelab.yaml}"

mkdir -p "$(dirname "$OUT")"
ssh "debian@$CP" sudo cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/$CP/" > "$OUT"
echo "Wrote $OUT. Run: export KUBECONFIG=$OUT"
