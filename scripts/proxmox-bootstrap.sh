#!/usr/bin/env bash
# run as root on ajserver2, safe to rerun
set -euo pipefail

NODE=ajserver2
POOL=k8s
TF_USER=terraform@pve
TOKEN=tf
VM_ROLE=TerraformVM
INFRA_ROLE=TerraformInfra
BRIDGE_PATH=/sdn/zones/localnetwork/vmbr0

VM_PRIVS="VM.Allocate,VM.Audit,VM.PowerMgmt,VM.GuestAgent.Audit,\
VM.Config.CPU,VM.Config.Memory,VM.Config.Disk,VM.Config.Network,\
VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.Options,VM.Config.HWType"

INFRA_PRIVS="Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,\
SDN.Use,Sys.Audit,Sys.AccessNetwork"

exists() { pvesh get "$1" >/dev/null 2>&1; }

set_role() {
  if exists "/access/roles/$1"; then
    pveum role modify "$1" --privs "$2"
  else
    pveum role add "$1" --privs "$2"
  fi
}

exists "/pools/$POOL" || pveum pool add "$POOL" --comment "Terraform-managed Kubernetes VMs"
exists "/access/users/$TF_USER" || pveum user add "$TF_USER" --comment "Terraform (API token only)"

set_role "$VM_ROLE" "$VM_PRIVS"
set_role "$INFRA_ROLE" "$INFRA_PRIVS"

pveum acl modify "/pool/$POOL" --users "$TF_USER" --roles "$VM_ROLE"
for path in /storage/local /storage/local-lvm "$BRIDGE_PATH" "/nodes/$NODE"; do
  pveum acl modify "$path" --users "$TF_USER" --roles "$INFRA_ROLE"
done

if exists "/access/users/$TF_USER/token/$TOKEN"; then
  echo "Token $TF_USER!$TOKEN exists; its secret is not shown again." >&2
  echo "To rotate: pveum user token remove $TF_USER $TOKEN, then re-run." >&2
else
  pveum user token add "$TF_USER" "$TOKEN" --privsep 0
fi
