resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

locals {
  cp_ip = var.nodes["cp-1"].ip
  wk_ip = var.nodes["wk-1"].ip

  # Token goes in a file, not the command line, so provisioner output isn't suppressed as sensitive.
  stage_token = [
    "cloud-init status --wait > /dev/null || true",
    "sudo install -D -m 600 /tmp/k3s-token /etc/rancher/k3s/cluster-token",
    "rm /tmp/k3s-token",
  ]
}

resource "terraform_data" "k3s_server" {
  triggers_replace = [proxmox_virtual_environment_vm.node["cp-1"].id, var.k3s_version]

  connection {
    type        = "ssh"
    host        = local.cp_ip
    user        = "debian"
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "file" {
    content     = random_password.k3s_token.result
    destination = "/tmp/k3s-token"
  }

  # Built-in CNI, network policy, kube-proxy, Traefik and ServiceLB are off; Cilium replaces them in P1.3.
  provisioner "remote-exec" {
    inline = concat(local.stage_token, [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} sh -s - server --token-file /etc/rancher/k3s/cluster-token --node-ip ${local.cp_ip} --tls-san ${local.cp_ip} --flannel-backend=none --disable-network-policy --disable-kube-proxy --disable=traefik --disable=servicelb",
    ])
  }
}

resource "terraform_data" "k3s_agent" {
  triggers_replace = [proxmox_virtual_environment_vm.node["wk-1"].id, terraform_data.k3s_server.id]

  connection {
    type        = "ssh"
    host        = local.wk_ip
    user        = "debian"
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "file" {
    content     = random_password.k3s_token.result
    destination = "/tmp/k3s-token"
  }

  provisioner "remote-exec" {
    inline = concat(local.stage_token, [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} K3S_URL=https://${local.cp_ip}:6443 sh -s - agent --token-file /etc/rancher/k3s/cluster-token --node-ip ${local.wk_ip}",
    ])
  }
}
