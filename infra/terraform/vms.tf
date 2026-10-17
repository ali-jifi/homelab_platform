resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  pool_id   = var.pool_id

  # The Debian cloud image has no qemu-guest-agent, so shutdown would hang; stop instead.
  stop_on_destroy = true
  agent {
    enabled = false
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.debian.id
    interface    = "scsi0"
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge = "vmbr0"
  }

  # Debian cloud images log to ttyS0.
  serial_device {}

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.gateway]
    }

    user_account {
      username = "debian"
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }
  }
}
