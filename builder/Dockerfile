# Golden Image Builder — Packer container for K8s Jobs
#
# DECISION: Use hashicorp/packer as base image.
# Why: Upstream Packer binary + Alpine = minimal image size.
#      Ansible runs ON the remote Hetzner server (via ansible-local provisioner),
#      NOT inside this container. We only need Packer + SSH.
#
# Usage (standalone):
#   docker run -e HCLOUD_TOKEN=xxx \
#     ghcr.io/mbilan1/golden-image-builder:latest
#
# Usage (K8s Job — created by golden-image-controller):
#   The controller creates Jobs with env vars from Cloud Credentials + Helm values.
#   Omitted env vars fall back to rke2-base.pkr.hcl defaults.

FROM hashicorp/packer:1.12

# NOTE: Only bash + openssh-client are needed.
# curl/jq were removed — cache checking is handled by the controller (DES-004),
# not by the entrypoint script.
RUN apk add --no-cache \
    bash \
    openssh-client

WORKDIR /workspace

# Copy Packer template and Ansible playbook
COPY rke2-base.pkr.hcl .
COPY ansible/ ansible/
COPY scripts/ scripts/

# Pre-install Packer plugins (hcloud + ansible) at build time
RUN packer init rke2-base.pkr.hcl

COPY builder/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
