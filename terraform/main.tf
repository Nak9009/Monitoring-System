provider "proxmox" {
  endpoint = var.proxmox_api_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

module "proxmox_vms" {
  source           = "./modules/proxmox-vm"
  count            = var.target_provider == "proxmox" ? var.vm_count : 0
  vm_name          = "${var.vm_name_prefix}-${count.index + 1}"
  cores            = var.vm_cpu_cores
  memory           = var.vm_memory_mb
  disk_size        = var.vm_disk_size_gb
  ssh_public_keys  = var.ssh_public_keys
}

module "vsphere_vms" {
  source           = "./modules/vsphere-vm"
  count            = var.target_provider == "vsphere" ? var.vm_count : 0
  vm_name          = "${var.vm_name_prefix}-${count.index + 1}"
  cores            = var.vm_cpu_cores
  memory           = var.vm_memory_mb
  disk_size        = var.vm_disk_size_gb
  datacenter       = var.vsphere_datacenter
}
