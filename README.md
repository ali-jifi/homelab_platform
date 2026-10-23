# homelab_platform

A two-node k3s cluster on Proxmox, built by Terraform and managed with GitOps (Argo CD), with Cilium networking, SOPS-encrypted secrets, Tailscale access and Prometheus/Grafana monitoring.

## Rebuild from zero

`scripts/rebuild.sh warm|cold` destroys both cluster VMs and rebuilds everything, writing per-stage timings to `timings/rebuild.csv`.

**"Zero" means:** no cluster VMs and no Kubernetes state. Two things are assumed to exist and are not rebuilt:

- **The anchor container** (CT 210, Postgres) that holds Terraform state. It is created by root outside the Terraform pool, so Terraform cannot destroy it.
- **The age private key** (`~/.config/sops/age/keys.txt`). It is the only secret not stored in Git; every other secret is SOPS-encrypted in the repo.

**Modes:**

- `warm`: the Debian cloud image stays on Proxmox.
- `cold`: the image is deleted first and downloaded again.

**Stages:** preflight, destroy, Tailscale device cleanup, (cold only) image delete, image, VMs + k3s, kubeconfig, Cilium, Argo CD, all apps synced and healthy.

## Timings

<!-- filled in after 3 warm + 3 cold runs -->
