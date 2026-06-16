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

variable "datacenter" {
  description = "Name of the vSphere datacenter"
  type        = string
}
