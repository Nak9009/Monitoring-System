variable "vm_name" {
  description = "The name of the VM"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory size in MB"
  type        = number
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject"
  type        = list(string)
}
