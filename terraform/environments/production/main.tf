module "monitoring_stack_production" {
  source           = "../../"
  target_provider  = var.target_provider
  vm_count         = var.vm_count
  vm_name_prefix   = var.vm_name_prefix
  vm_cpu_cores     = var.vm_cpu_cores
  vm_memory_mb     = var.vm_memory_mb
  vm_disk_size_gb  = var.vm_disk_size_gb
  ssh_public_keys  = var.ssh_public_keys
}
