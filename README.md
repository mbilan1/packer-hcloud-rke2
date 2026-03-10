# packer-hcloud-rke2

[![Lint: Packer](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/lint-packer.yml/badge.svg)](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/lint-packer.yml)
[![SAST: Checkov](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/sast-checkov.yml/badge.svg)](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/sast-checkov.yml)
[![SAST: KICS](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/sast-kics.yml/badge.svg)](https://github.com/mbilan1/packer-hcloud-rke2/actions/workflows/sast-kics.yml)

<!-- Version badges — source: rke2-base.pkr.hcl (required_plugins) -->
![Packer](https://img.shields.io/badge/Packer-HCL2-02A8EF?logo=packer&logoColor=white)
![hcloud plugin](https://img.shields.io/badge/hcloud-%3E%3D1.6.0-E10000?logo=hetzner&logoColor=white)
![ansible plugin](https://img.shields.io/badge/ansible-%3E%3D1.1.0-EE0000?logo=ansible&logoColor=white)

> **⚠️ Experimental (Beta)** — This is an **unofficial** community implementation, under active development and **not production-ready**.
> Image contents, Ansible roles, and behavior may change without notice. Use at your own risk.
> No stability guarantees are provided until v1.0.0.

Builds a Hetzner Cloud snapshot with pre-installed packages and hardened settings for RKE2 nodes.

## Ecosystem

This Packer template is part of the **RKE2-on-Hetzner** ecosystem — a set of interconnected projects that together provide a complete Kubernetes management platform on Hetzner Cloud.

| Repository | Role in Ecosystem |
|---|---|
| [`terraform-hcloud-rke2-core`](https://github.com/mbilan1/terraform-hcloud-rke2-core) | L3 infrastructure primitive — servers, network, readiness |
| [`terraform-hcloud-rancher`](https://github.com/mbilan1/terraform-hcloud-rancher) | Management cluster — Rancher + Node Driver on RKE2 |
| [`rancher-hetzner-cluster-templates`](https://github.com/mbilan1/rancher-hetzner-cluster-templates) | Downstream cluster provisioning via Rancher UI |
| **`packer-hcloud-rke2`** (this repo) | **Packer node image — CIS-hardened snapshots** |

```
rke2-core (L3 infra) → rancher (L3+L4 management) → cluster-templates (downstream via UI)
                                                    ↑
                                        packer (node images)
```

## Snapshot Naming

Snapshots are auto-named from build parameters for traceability:

| Build | Snapshot Name Example |
|-------|----------------------|
| Standard | `ubuntu-2404-rke2-v1.34.4-1772749791` |
| CIS hardened | `ubuntu-2404-rke2-v1.34.4-cis-l1-1772749791` |
| Custom override | `my-custom-name-1772749791` |

Format: `{os}{version}-rke2-{rke2_version}[-cis-l1]-{timestamp}`

Override with `-var image_name=my-name` when needed.

## What Gets Baked In (Always)

- **etcd user** — CIS minimum compliance (always present, even without full CIS)
- **open-iscsi, nfs-common** — Longhorn prerequisites
- **Kernel modules** — `iscsi_tcp`, `br_netfilter`, `overlay`
- **sysctl tuning** — IP forwarding, bridge-nf-call, inotify limits, CIS kernel params
- **RKE2 binaries** — server + agent pre-downloaded (saves ~2-3 min at boot)

## CIS Hardening (Optional)

When `enable_cis_hardening=true`, additionally applies CIS Level 1 (Ubuntu 24.04 benchmark v1.0.0).

## Usage

```bash
export PKR_VAR_hcloud_token="your-token-here"

packer init rke2-base.pkr.hcl

# Standard image — ~5 min
# → ubuntu-2404-rke2-v1.34.4-<timestamp>
packer build rke2-base.pkr.hcl

# CIS-hardened image — ~15 min
# → ubuntu-2404-rke2-v1.34.4-cis-l1-<timestamp>
packer build -var enable_cis_hardening=true rke2-base.pkr.hcl

# Custom name override
# → my-image-<timestamp>
packer build -var enable_cis_hardening=true -var image_name=my-image rke2-base.pkr.hcl
```

## After Building

Use the snapshot name/ID in your Helm chart values or Terraform:

```yaml
# rancher-hetzner-cluster-templates values.yaml
hetzner:
  image: "ubuntu-2404-rke2-v1.34.4-cis-l1-1772749791"  # snapshot name from packer output
```

## CIS Hardening Flow for Downstream Clusters

Hetzner Cloud snapshots are **project-scoped** — a snapshot built in one Hetzner project
is not visible from another. For each downstream Hetzner project that needs CIS-hardened
nodes, run Packer with that project's API token.

### Step-by-step

```
1. Build the node image (once per Hetzner project, repeat when RKE2 version or CIS updates):

   export HCLOUD_TOKEN="<downstream-project-token>"
   packer build -var "hcloud_token=$HCLOUD_TOKEN" -var enable_cis_hardening=true .
   # → Output: "A snapshot was created: 'ubuntu2404-rke2-v1324-cis-l1-1772749791' (ID: 555666)"

2. Note the snapshot ID (e.g. 555666) or name from the output.

3. In Rancher UI → Create Cluster → Hetzner Template:
   - Select the Cloud Credential for the same Hetzner project
   - In "Machine Image" field, enter the snapshot ID: 555666
   - Fill remaining fields and click Create

4. Rancher provisions nodes from the CIS-hardened snapshot.
```

### Multiple projects

```bash
# Script to build node image across all downstream projects
for project in prod staging dev; do
  echo "=== Building for: $project ==="
  packer build \
    -var "hcloud_token=${!project_token}" \
    -var "enable_cis_hardening=true" \
    .
done
# Each project gets its own snapshot with its own ID.
# Use the respective snapshot ID when creating clusters in that project.
```

### When to rebuild

| Event | Rebuild? |
|-------|----------|
| New RKE2 version | Yes |
| CIS benchmark update | Yes |
| Ubuntu security patch | Yes |
| Creating another cluster in the same project | No — reuse existing snapshot |
| New Hetzner project | Yes — one build per project |

## Golden Image Controller (DES-004)

In addition to standalone Packer builds, this repository includes a **Kubernetes controller**
that automates snapshot creation. When a downstream cluster's `HetznerConfig` uses the
`golden:*` image convention (e.g., `golden:cis`), the controller:

1. Checks the Hetzner API for a cached snapshot with matching labels
2. If cache miss — creates a K8s Job that runs Packer inside the builder container
3. Patches the `HetznerConfig` with the resolved snapshot ID
4. Unpauses the machine pool so Rancher can provision nodes

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| **Builder** | `builder/` | Docker image (Packer + Ansible) for K8s Jobs |
| **Controller** | `controller/` | Go controller watching HetznerConfig CRDs |
| **Chart** | `chart/golden-image-controller/` | Helm chart for deploying the controller |

### Source of Truth for Defaults

Build parameters (RKE2 version, location, server type, base image) are configured in **exactly two places** — one per usage path:

| Path | Source of truth | How it flows |
|------|----------------|-------------|
| **Standalone Packer** | `rke2-base.pkr.hcl` variables | User → `packer build` → pkr.hcl defaults |
| **Controller (K8s)** | `chart/values.yaml` → `defaults` | Helm values → deployment env → controller → Job env → Packer |

The builder entrypoint and controller binary have **no hardcoded defaults** — they pass through
env vars to Packer. Omitted values fall back to `rke2-base.pkr.hcl` defaults.

## Directory Structure

```
├── rke2-base.pkr.hcl              # Packer template (source of truth for standalone builds)
├── scripts/
│   └── install-ansible.sh          # Bootstrap Ansible + Galaxy deps
├── ansible/
│   ├── playbook.yml                # Main playbook (2-phase: base + optional CIS)
│   ├── requirements.yml            # Galaxy dependencies
│   └── roles/
│       ├── rke2-base/              # Always: packages, kernel, RKE2, etcd user
│       │   ├── defaults/main.yml
│       │   └── tasks/main.yml
│       └── cis-hardening/          # Optional: CIS Level 1 wrapper
│           ├── defaults/main.yml
│           ├── vars/main.yml
│           └── tasks/main.yml
├── builder/
│   ├── Dockerfile                   # Packer container for K8s Jobs
│   └── entrypoint.sh               # Thin wrapper — passes env vars to Packer
├── controller/
│   ├── main.go                      # HetznerConfig reconciler (Go)
│   ├── Dockerfile                   # Multi-stage build (distroless)
│   └── go.mod
├── chart/
│   └── golden-image-controller/     # Helm chart (source of truth for controller path)
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── README.md
```
