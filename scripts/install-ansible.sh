#!/bin/bash
# Install Ansible and dependencies on the Packer build instance.
set -euo pipefail

apt-get update -q
apt-get install -q -y software-properties-common git
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -q -y ansible
ansible --version

# Install Galaxy collections and roles from requirements.yml
if [ -f /tmp/packer-files/ansible/requirements.yml ]; then
  echo ">>> Installing Ansible Galaxy dependencies from requirements.yml..."
  ansible-galaxy collection install -r /tmp/packer-files/ansible/requirements.yml --force
  ansible-galaxy role install -r /tmp/packer-files/ansible/requirements.yml --force
  echo ">>> Galaxy dependencies installed."
else
  echo ">>> No requirements.yml found — skipping Galaxy install."
fi
