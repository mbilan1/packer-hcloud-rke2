# ──────────────────────────────────────────────────────────────────────────────
# Packer template: RKE2 Golden Image for Hetzner Cloud
#
# Builds a Hetzner Cloud snapshot with:
#   - Always: etcd user, kernel modules, sysctl params, RKE2 binaries
#   - Optional (enable_cis_hardening=true): Full CIS Level 1 hardening
#
# DECISION: Separate repository/directory from rke2-core.
# Why: Golden Image creation is an independent workflow with its own lifecycle.
#      rke2-core stays a clean infrastructure module; Packer is an operational
#      tool that produces artifacts (snapshots) consumed by both terraform
#      modules and Rancher Node Driver.
# ──────────────────────────────────────────────────────────────────────────────

packer {
  required_plugins {
    hcloud = {
      version = ">= 1.6.0"
      source  = "github.com/hetznercloud/hcloud"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Variables
#
# DECISION: These defaults are the single source of truth for STANDALONE Packer builds.
# For the controller (K8s) path, defaults live in chart/golden-image-controller/values.yaml.
# Do NOT duplicate these values in builder/entrypoint.sh or controller/main.go.
# ──────────────────────────────────────────────────────────────────────────────

variable "hcloud_token" {
  description = "Hetzner Cloud API token with read/write access."
  type        = string
  sensitive   = true
}

variable "base_image" {
  description = "Source OS image. Must be Ubuntu LTS supported by RKE2."
  type        = string
  default     = "ubuntu-24.04"

  validation {
    condition     = can(regex("^ubuntu-", var.base_image))
    error_message = "Only Ubuntu images are supported."
  }
}

variable "server_type" {
  description = "Hetzner server type for the temporary build instance."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter for the build server. Snapshot is location-independent."
  type        = string
  default     = "hel1"
}

variable "image_name" {
  description = "Override for the snapshot name prefix. When empty (default), an informative name is auto-generated: ubuntu-2404-rke2-v1.34.4-cis-l1-{{timestamp}}."
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "RKE2 release tag to pre-install. Must match the cluster's kubernetes version."
  type        = string
  default     = "v1.34.4+rke2r1"
}

variable "enable_cis_hardening" {
  description = "Enable full CIS Level 1 hardening (UBUNTU24-CIS benchmark). etcd user and kernel params are ALWAYS applied regardless of this flag."
  type        = bool
  default     = false
}

# ──────────────────────────────────────────────────────────────────────────────
# Snapshot naming — auto-generated from build parameters
#
# Examples:
#   CIS enabled:  ubuntu-2404-rke2-v1.34.4-cis-l1-1772749791
#   CIS disabled: ubuntu-2404-rke2-v1.34.4-1772749791
#   Override:     my-custom-name-1772749791
# ──────────────────────────────────────────────────────────────────────────────
locals {
  os_tag     = replace(var.base_image, ".", "")      # ubuntu-24.04 → ubuntu-2404
  rke2_ver   = split("+", var.kubernetes_version)[0] # v1.34.4+rke2r1 → v1.34.4
  cis_suffix = var.enable_cis_hardening ? "-cis-l1" : ""

  auto_snapshot_name = "${local.os_tag}-rke2-${local.rke2_ver}${local.cis_suffix}"
  snapshot_name      = var.image_name != "" ? var.image_name : local.auto_snapshot_name
}

source "hcloud" "rke2_base" {
  token       = var.hcloud_token
  image       = var.base_image
  location    = var.location
  server_type = var.server_type
  server_name = "packer-rke2-base-{{timestamp}}"

  snapshot_name = "${local.snapshot_name}-{{timestamp}}"

  # NOTE: These labels are the contract between Packer (writes) and the controller (reads).
  # controller/main.go → findSnapshot() queries by: managed-by, rke2-version, cis-hardened.
  # If you add/rename labels here, update findSnapshot() to match.
  snapshot_labels = {
    "managed-by"    = "packer"
    "role"          = "rke2-base"
    "base-image"    = var.base_image
    "rke2-version"  = replace(var.kubernetes_version, "+", "-")
    "cis-hardened"  = var.enable_cis_hardening ? "true" : "false"
    "cis-benchmark" = var.enable_cis_hardening ? "UBUNTU24-CIS-v1.0.0-L1" : "none"
  }

  ssh_username = "root"
}

build {
  sources = ["source.hcloud.rke2_base"]

  # Upload Ansible files to the build instance
  provisioner "shell" {
    inline = ["mkdir -p /tmp/packer-files/ansible"]
  }

  provisioner "file" {
    source      = "ansible/"
    destination = "/tmp/packer-files/ansible/"
  }

  # Install Ansible + Galaxy dependencies
  provisioner "shell" {
    script = "scripts/install-ansible.sh"
  }

  # Write Ansible extra-vars JSON file for ansible-core 2.20+ boolean handling
  provisioner "shell" {
    inline = [
      "echo '{\"ubtu24cis_rule_5_4_2_5\": false}' > /tmp/ansible-overrides.json"
    ]
  }

  # Run Ansible playbook
  provisioner "ansible-local" {
    playbook_file = "ansible/playbook.yml"
    role_paths = [
      "ansible/roles/rke2-base",
      "ansible/roles/cis-hardening",
    ]
    extra_arguments = [
      "--extra-vars", "kubernetes_version=${var.kubernetes_version}",
      "--extra-vars", "enable_cis_hardening=${var.enable_cis_hardening}",
      "--extra-vars", "ansible_user=root",
      "--extra-vars", "@/tmp/ansible-overrides.json",
    ]
  }

  # Clean up for snapshot
  provisioner "shell" {
    inline = [
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
      "cloud-init clean --logs --seed",
      "sync",
    ]
  }
}
