#!/usr/bin/env bash
# Golden Image Builder entrypoint — runs as a K8s Job payload.
#
# Single responsibility: run Packer build. Cache checking is handled by the
# controller BEFORE creating the Job. This script does NOT duplicate that logic.
#
# Required env vars:
#   HCLOUD_TOKEN       — Hetzner Cloud API token
#
# Optional env vars (omit to use rke2-base.pkr.hcl defaults):
#   RKE2_VERSION       — RKE2 release tag
#   ENABLE_CIS         — Enable CIS Level 1 hardening (true/false)
#   BASE_IMAGE         — Source OS image
#   LOCATION           — Hetzner datacenter for build server
#   SERVER_TYPE        — Hetzner server type for build server
#
# DECISION: No hardcoded defaults here.
# Why: Defaults live in two places only:
#   - Standalone Packer: rke2-base.pkr.hcl variable defaults
#   - Controller path:   chart/golden-image-controller/values.yaml
# This script is a thin wrapper — it passes through env vars to Packer.
# If an env var is unset, Packer uses its own default from rke2-base.pkr.hcl.
set -euo pipefail

: "${HCLOUD_TOKEN:?HCLOUD_TOKEN is required}"

echo "=== Golden Image Builder ==="
echo "RKE2: ${RKE2_VERSION:-<pkr.hcl default>} | CIS: ${ENABLE_CIS:-<pkr.hcl default>} | Base: ${BASE_IMAGE:-<pkr.hcl default>} | Location: ${LOCATION:-<pkr.hcl default>}"

# ── Build Packer args — only pass non-empty env vars ─────────────────────────
# DECISION: Conditional -var flags instead of hardcoded defaults.
# Why: If env var is unset, Packer uses its own default from rke2-base.pkr.hcl.
#      This keeps rke2-base.pkr.hcl as the single source of truth for standalone builds.

PACKER_ARGS=(-var "hcloud_token=${HCLOUD_TOKEN}")
[[ -n "${RKE2_VERSION:-}" ]]  && PACKER_ARGS+=(-var "kubernetes_version=${RKE2_VERSION}")
[[ -n "${ENABLE_CIS:-}" ]]    && PACKER_ARGS+=(-var "enable_cis_hardening=${ENABLE_CIS}")
[[ -n "${BASE_IMAGE:-}" ]]    && PACKER_ARGS+=(-var "base_image=${BASE_IMAGE}")
[[ -n "${LOCATION:-}" ]]      && PACKER_ARGS+=(-var "location=${LOCATION}")
[[ -n "${SERVER_TYPE:-}" ]]   && PACKER_ARGS+=(-var "server_type=${SERVER_TYPE}")

echo ">>> Starting Packer build..."
echo ">>> This will create a temporary Hetzner server, provision it, and snapshot it."
echo ">>> Expected duration: ~5 min (base) or ~12 min (CIS hardened)."

cd /workspace
packer build "${PACKER_ARGS[@]}" .

echo "=== Build complete ==="
