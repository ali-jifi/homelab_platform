# Pinned build so a rebuild always gets the same image. Checksum from the build's SHA512SUMS.
resource "proxmox_download_file" "debian" {
  node_name          = var.proxmox_node
  datastore_id       = "local"
  content_type       = "import"
  url                = "https://cloud.debian.org/images/cloud/trixie/20261017-2634/debian-13-genericcloud-amd64-20261017-2634.qcow2"
  checksum           = "ec584ccabfef7120b4c4f7482adf0e615894d9292cedec446b64194b951ebe5dd97c336b5dcbae458333764b0edd516334506017f33c4f2020ef8d38b569ffe3"
  checksum_algorithm = "sha512"
}
