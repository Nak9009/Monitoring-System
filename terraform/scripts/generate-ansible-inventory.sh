#!/usr/bin/env bash
# ==============================================================================
# Generate Ansible Inventory from Terraform State
# Parses Terraform outputs to build a dynamic inventory file for Ansible.
# ==============================================================================

set -euo pipefail

# Path configurations
TERRAFORM_DIR="$(dirname "$0")/../environments/production"
ANSIBLE_INVENTORY_FILE="$(dirname "$0")/../../ansible/inventory/hosts.yml"

echo "Reading Terraform output state..."
cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No terraform.tfstate found. Please run 'terraform apply' first."
    exit 1
fi

VM_IPS=$(terraform output -json vm_ips | tr -d '[]" ' | tr ',' '\n')
VM_NAMES=$(terraform output -json vm_hostnames | tr -d '[]" ' | tr ',' '\n')

if [ -z "$VM_IPS" ] || [ -z "$VM_NAMES" ]; then
    echo "Error: Could not retrieve VM IPs or Hostnames from Terraform state."
    exit 1
fi

# Convert to arrays
IFS=$'\n' read -rd '' -a IPS_ARR <<< "$VM_IPS" || true
IFS=$'\n' read -rd '' -a NAMES_ARR <<< "$VM_NAMES" || true

echo "Generating Ansible inventory..."

# Start creating inventory file content
cat <<EOF > "$ANSIBLE_INVENTORY_FILE"
all:
  children:
    monitoring_servers:
      hosts:
EOF

for i in "${!IPS_ARR[@]}"; do
    NAME="${NAMES_ARR[$i]}"
    IP="${IPS_ARR[$i]}"
    cat <<EOF >> "$ANSIBLE_INVENTORY_FILE"
        $NAME:
          ansible_host: $IP
EOF
done

# Add placeholder groups for dynamic mapping
cat <<EOF >> "$ANSIBLE_INVENTORY_FILE"
    linux_servers:
      hosts:
        # Auto-discovered hosts can go here
    windows_servers:
      hosts:
        # Windows servers can go here
EOF

echo "Ansible inventory successfully generated at $ANSIBLE_INVENTORY_FILE"
