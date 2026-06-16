# Configure local backend for Terraform state persistence
# In enterprise settings, migrate this to an S3 bucket or Terraform Cloud
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
