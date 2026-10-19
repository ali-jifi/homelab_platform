variable "proxmox_endpoint" {
  type    = string
  default = "https://ajserver2:8006/"
}

variable "proxmox_node" {
  type    = string
  default = "ajserver2"
}

variable "pool_id" {
  type    = string
  default = "k8s"
}

variable "gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

variable "k3s_version" {
  type    = string
  default = "v1.36.5+k3s1"
}

variable "nodes" {
  type = map(object({
    vm_id     = number
    ip        = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {
    cp-1 = { vm_id = 201, ip = "192.168.0.201", cores = 2, memory_mb = 3072, disk_gb = 32 }
    wk-1 = { vm_id = 202, ip = "192.168.0.202", cores = 4, memory_mb = 7168, disk_gb = 200 }
  }
}
