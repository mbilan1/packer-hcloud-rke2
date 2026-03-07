# Claude Instructions — packer-hcloud-rke2

> Single source of truth for AI agents working on this repository.
> AGENTS.md redirects here. Read this file in full before any task.

---

## What This Repository Is

A **Packer template** that builds RKE2 node images (Hetzner Cloud snapshots) with optional CIS hardening.

- **Tool**: Packer (HCL format)
- **Cloud provider**: Hetzner Cloud
- **Provisioner**: Ansible (playbook in `ansible/`)
- **Output**: Hetzner Cloud snapshot with RKE2 pre-installed
- **Status**: Active development

### What This Template Does

1. Creates a temporary builder server on Hetzner Cloud
2. Runs the Ansible playbook: system prep → RKE2 install → CIS hardening → cleanup
3. Creates a labeled snapshot from the server
4. Destroys the builder server (Packer handles this automatically)

### What This Template Does NOT Do

| Out of scope | Why |
|---|---|
| Start RKE2 | RKE2 config comes from cloud-init at boot time |
| Manage cluster state | No state files — Packer is stateless |
| Deploy to downstream projects | Snapshots are project-scoped (see ADR-009) |
| Install CCM/CSI | Those are cluster-level addons, not node-level |

---

## Sibling Repositories

| Repo | Purpose |
|---|---|
| `terraform-hcloud-rke2-core` | L3 infrastructure — consumes snapshots via `hcloud_image` |
| `terraform-hcloud-rancher` | Management cluster (uses snapshots for management nodes) |
| `rancher-hetzner-cluster-templates` | Downstream cluster templates (specify snapshot ID) |
| `rke2-hetzner-architecture` | Architecture decisions (ADR-009: golden image delivery) |
| `hcloud-image-replicator` | Cross-project snapshot replication (prototype) |

---

## Critical Rules

### NEVER:
1. **Do NOT run `packer build`** without explicit user approval — creates real infrastructure
2. **Do NOT commit** API tokens, SSH keys, or `.pkrvars.hcl` files with secrets
3. **Do NOT start RKE2** in the playbook — it must only be installed, not running
4. **A question is NOT a request to change code**

### ALWAYS:
1. **Run `packer validate .`** after any `.pkr.hcl` file change
2. **Run `packer fmt -check .`** to verify formatting
3. **Read the relevant file before editing**

---

## Build Usage

```bash
# Initialize plugins
packer init .

# Validate template
packer validate .

# Build (requires HCLOUD_TOKEN or -var)
packer build -var "hcloud_token=$HCLOUD_TOKEN" .

# Build without CIS hardening
packer build -var "hcloud_token=$HCLOUD_TOKEN" -var "enable_cis_hardening=false" .

# Build with custom RKE2 version
packer build \
  -var "hcloud_token=$HCLOUD_TOKEN" \
  -var "rke2_version=v1.32.4+rke2r1" \
  -var 'snapshot_name=rke2-v1.32.4-cis' .
```

---

## Code Style

- **Packer formatting**: `packer fmt` canonical style
- **Variable naming**: `snake_case`
- **Ansible**: YAML with `name` on every task

### Git Commit Convention

```
<type>(<scope>): <short summary>
```
Types: `feat`, `fix`, `docs`, `refactor`, `chore`
Scopes: `packer`, `ansible`, `docs`

---

## Language

- **Code & comments**: English
- **Commits**: English, Conventional Commits
- **User communication**: respond in the user's language
