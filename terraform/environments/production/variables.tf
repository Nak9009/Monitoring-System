variable "target_provider" {
  description = "Target hypervisor provider: 'proxmox' or 'vsphere'"
  type        = string
}

variable "vm_count" {
  description = "Number of monitoring server VMs to deploy"
  type        = number
}

variable "vm_name_prefix" {
  description = "Prefix for the VM names"
  type        = string
}

variable "vm_cpu_cores" {
  description = "vCPU count per VM"
  type        = number
}

variable "vm_memory_mb" {
  description = "Memory size in MB per VM"
  type        = number
}

variable "vm_disk_size_gb" {
  description = "OS disk size in GB per VM"
  type        = number
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject"
  type        = list(string)
}
