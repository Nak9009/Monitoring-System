output "vm_ips" {
  description = "Assigned IP addresses of the provisioned VMs"
  value = var.target_provider == "proxmox" ? module.proxmox_vms[*].ip_address : module.vsphere_vms[*].ip_address
}

output "vm_hostnames" {
  description = "Hostnames of the provisioned VMs"
  value = var.target_provider == "proxmox" ? module.proxmox_vms[*].hostname : module.vsphere_vms[*].hostname
}
