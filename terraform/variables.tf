variable "target_provider" {
  description = "Target hypervisor provider: 'proxmox' or 'vsphere'"
  type        = string
  default     = "proxmox"
}

# --- Proxmox Connection Variables ---
variable "proxmox_api_endpoint" {
  description = "The Proxmox API endpoint"
  type        = string
  default     = "https://proxmox.internal:8006/api2/json"
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
  default     = ""
}

# --- vSphere Connection Variables ---
variable "vsphere_server" {
  description = "vCenter or vSphere host address"
  type        = string
  default     = "vcenter.internal"
}

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
  default     = "administrator@vsphere.local"
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vsphere_datacenter" {
  description = "vSphere Datacenter name"
  type        = string
  default     = "Datacenter"
}

# --- VM Configuration Variables ---
variable "vm_count" {
  description = "Number of monitoring server VMs to deploy"
  type        = number
  default     = 2
}

variable "vm_name_prefix" {
  description = "Prefix for the VM names"
  type        = string
  default     = "mon"
}

variable "vm_cpu_cores" {
  description = "vCPU count per VM"
  type        = number
  default     = 8
}

variable "vm_memory_mb" {
  description = "Memory size in MB per VM"
  type        = number
  default     = 16384
}

variable "vm_disk_size_gb" {
  description = "OS disk size in GB per VM"
  type        = number
  default     = 500
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject into the VM"
  type        = list(string)
  default     = []
}
