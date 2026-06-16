output "ip_address" {
  description = "IP address of the provisioned Proxmox VM"
  value       = proxmox_virtual_environment_vm.monitoring_vm.ipv4_addresses[1][0]
}

output "hostname" {
  description = "Hostname of the provisioned Proxmox VM"
  value       = proxmox_virtual_environment_vm.monitoring_vm.name
}
