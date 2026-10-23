#!/usr/bin/env bash
# renders every helm chart in platform/apps with the same version + values argo uses
# output: one file per app in the given dir (default rendered/), for kubeconform to check
# needs helm + yq. KSOPS folders are skipped, CI has no age key to decrypt them
set -euo pipefail

out="${1:-rendered}"
mkdir -p "$out"

for app in platform/apps/*.yaml; do
  name=$(yq '.metadata.name' "$app")
  src='.spec.sources[] | select(has("chart"))'

  chart=$(yq "$src | .chart" "$app")
  [ -z "$chart" ] && continue

  repo=$(yq "$src | .repoURL" "$app")
  version=$(yq "$src | .targetRevision" "$app")
  release=$(yq "$src | .helm.releaseName" "$app")
  namespace=$(yq '.spec.destination.namespace' "$app")

  args=()
  while read -r f; do
    [ -n "$f" ] && args+=(-f "${f#\$values/}")
  done < <(yq "$src | .helm.valueFiles[]" "$app")

  echo "rendering $name ($chart $version)"
  helm template "$release" "$chart" --repo "$repo" --version "$version" \
    --namespace "$namespace" "${args[@]}" > "$out/$name.yaml"
done
