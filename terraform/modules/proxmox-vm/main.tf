resource "proxmox_virtual_environment_vm" "monitoring_vm" {
  name        = var.vm_name
  description = "Managed by Terraform — Enterprise Monitoring Server"
  tags        = ["monitoring", "production", "terraform"]
  node_name   = "pve"

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  agent {
    enabled = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      keys     = var.ssh_public_keys
      username = "ubuntu"
    }
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    size         = var.disk_size
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
    vlan_id = 100
  }

  lifecycle {
    prevent_destroy = true
  }
}
