output "ip_address" {
  description = "IP address of the provisioned vSphere VM"
  value       = vsphere_virtual_machine.monitoring_vm.default_ip_address
}

output "hostname" {
  description = "Hostname of the provisioned vSphere VM"
  value       = vsphere_virtual_machine.monitoring_vm.name
}
