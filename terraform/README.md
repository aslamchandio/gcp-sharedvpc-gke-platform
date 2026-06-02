# Shared VPC + Cross-Project Private GKE — Modular, Multi-Environment

Reusable Terraform modules that provision a **Shared VPC in a host project** and a
**private GKE cluster in a service project**, composed per environment under
`environments/dev/` and `environments/prod/`. Every resource is named with an
`it-<env>-*` convention so the two environments are visually and logically distinct.

```
terraform/
├── modules/
│   ├── apis/        # project service (API) enablement — host + service
│   ├── network/     # Shared VPC host+attach, subnets (slice), proxy subnet, Router+NAT, firewall
│   ├── iam/         # GKE robot identity, Shared-VPC subnet IAM (least-priv), dedicated node SA
│   └── gke/         # private cluster + system node pool (zonal/regional toggle, NAP)
├── environments/
│   ├── dev/         # fast, disposable               (state prefix: dev/shared-vpc-gke)
│   │   ├── main.tf  versions.tf  backend.tf  variables.tf  outputs.tf  locals.tf
│   │   ├── network.auto.tfvars   # projects, region, naming, labels, subnets, CIDRs
│   │   └── gke.auto.tfvars       # cluster, nodes, release, control-plane access
│   └── prod/        # REGIONAL, hardened             (state prefix: prod/shared-vpc-gke)
│       ├── main.tf  versions.tf  backend.tf  variables.tf  outputs.tf  locals.tf
│       ├── network.auto.tfvars
│       └── gke.auto.tfvars
└── compute-class.yaml   # Custom Compute Class (applied via ArgoCD, not Terraform)
```

> Env roots reference shared modules with `source = "../../modules/<name>"`.

Each environment is an independent **root module** with its own GCS state prefix.
Modules are shared and parameterised. State backend: GCS bucket
`aslam-terraform-bucket`, prefix per env.

---

## Architecture

```
┌────────────────────────── HOST project ──────────────────────────────┐
│  Shared VPC  (it-<env>-vpc)                                           │
│   ├─ gke subnet   <region>      primary + pods/services secondaries   │
│   ├─ dr  subnet   <dr-region>   plain (no GKE secondary ranges)       │
│   ├─ proxy subnet <region>      REGIONAL_MANAGED_PROXY (Gateway API)  │
│   ├─ Cloud Router + Cloud NAT   (egress for private nodes)            │
│   └─ Firewall: deny-all ingress baseline + internal + master→nodes    │
│                                                                       │
│  Control-plane /28 → declared on the cluster (peered Google VPC),     │
│  NOT a subnet. IAM: GKE robot + cloudservices SAs get                 │
│  compute.networkUser (scoped to the gke subnet) + hostServiceAgentUser│
└───────────────────────────────┬───────────────────────────────────────┘
                                 │ Shared VPC attachment
┌───────────────────────────────┴──── SERVICE project ─────────────────┐
│  Private GKE (VPC-native, Dataplane V2, Workload Identity, Shielded)  │
│   ├─ dev : ZONAL control plane, 1 zone, 1 node   → fast to build      │
│   ├─ prod: REGIONAL control plane (3-zone HA), node pool sized to fit │
│   ├─ system pool (it-<env>-standard-system): dedicated node SA,       │
│   │   GKE_METADATA, Shielded, single-zone option                      │
│   └─ Node Auto-Provisioning (NAP) ← backs Custom Compute Classes      │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Variable design (how values flow)

This repo deliberately uses **two declaration layers + per-env value files**. It is
the standard production pattern; the "duplication" is module encapsulation, not waste.

```
network.auto.tfvars  ┐
gke.auto.tfvars      ┘  ASSIGN values (per env, auto-loaded)
        │
        ▼
dev|prod/variables.tf   DECLARE the env surface (so tfvars has a landing spot)
        │  main.tf:  module "gke" { node_machine_type = var.node_machine_type }
        ▼
modules/*/variables.tf  DECLARE the module contract (type + validation + description)
```

Rules used here:
- **`*.auto.tfvars`** hold the only values you edit per environment. Terraform
  auto-loads every `*.auto.tfvars` (alphabetically) — no `-var-file` flag needed.
- **Module variables** = required contract for anything an env tunes; defaults only
  for internal constants (`pods`/`services` range names, `node_iam_roles`, API lists,
  NAP limits).
- **Env-root variables** = thin declarations so tfvars can set them.
- Splitting `terraform.tfvars` into **`network.auto.tfvars`** + **`gke.auto.tfvars`**
  groups values by concern; both are loaded together.

### Naming / tagging convention (`dev|prod/locals.tf`)

```hcl
name             = "${business_division}-${environment_name}"   # e.g. it-prod
gke_cluster_name = "${name}-${cluster_name}"                    # e.g. it-prod-standard
network_name     = "${name}-vpc"                                # e.g. it-prod-vpc
proxy_subnet_name= "${name}-proxy"
# subnet names in tfvars are bare suffixes ("gke","eu") -> prefixed to it-prod-gke ...
common_tags      = { owners = business_division, environment = environment_name }
```

Because the `network` module derives Router/NAT/firewall names from `network_name`,
and `iam` derives the node SA from `cluster_name`, the `it-<env>-*` prefix flows to
**every** resource: `it-prod-vpc-router`, `it-prod-vpc-nat`,
`it-prod-vpc-deny-all-ingress`, `it-prod-standard-system`, `it-prod-standard-nodes`, …

---

## dev vs prod

| Setting | dev | prod | Why |
|---|---|---|---|
| `regional` | `false` (zonal) | `true` (3-zone HA) | Zonal skips control-plane replication → minutes faster to build |
| `node_zone_count` | `1` | `3` | Fewer node VMs |
| `system_node_count` | `1` | `1` | Single managed node (raise for HA) |
| `system_pool_single_zone` | `false` (already zonal) | `true` | Pins the pool's node to one zone |
| `node_machine_type` | `e2-standard-4` | `e2-standard-2` | Must fit system pods on one node (see Single-node tuning) |
| `region` | `us-west1` | `us-central1` | example separation |
| `default_pool_enabled` | `false` | `false` | Optional Spot pool currently **disabled** in both (see Node pools) |
| `deletion_protection` | `false` | `false`* | dev disposable; set prod `true` for real prod |

\* prod was left `false` during teardown work — **set it back to `true`** for a real
production cluster.

Security posture is identical in both: private nodes, Workload Identity, Shielded
nodes, Dataplane V2 (eBPF), deny-all ingress baseline, dedicated least-priv node SA.
**Gateway API** and **Dataplane V2 observability** (below) are also enabled
cluster-wide in both — they live in the shared `gke` module, not per-env tfvars.

---

## Gateway API & Dataplane V2 observability

Three cluster-wide features are enabled directly in the shared `gke` module
(`modules/gke/main.tf`), so **both dev and prod get them with no per-env tfvars** —
flip them in one place and every environment inherits the change.

| Feature | Terraform | What it gives you |
|---|---|---|
| **Gateway API** | `gateway_api_config { channel = "CHANNEL_STANDARD" }` | Installs the GA Gateway API CRDs + GKE controller → `gke-l7-*` GatewayClasses. Preferred over legacy Ingress; pairs with the proxy-only subnet already provisioned by the `network` module. |
| **Dataplane V2 metrics** | `monitoring_config { advanced_datapath_observability_config { enable_metrics = true } }` | Pod- and policy-level flow **metrics** exported to Cloud Monitoring. |
| **Dataplane V2 observability (relay)** | `…{ enable_relay = true }` | Flow-logging **relay (Hubble)** — surfaced in the GKE "DPv2 observability" UI and via `kubectl` flow queries. |

> Both DPv2 observability flags **require** `datapath_provider = "ADVANCED_DATAPATH"`
> (Dataplane V2), which this module already sets. Enabling them is an **in-place**
> cluster update (`1 to change`, no recreate) but the control-plane reconfig can take
> 10–20 min.

Verify:
```bash
kubectl get gatewayclass                       # expect gke-l7-* classes
gcloud container clusters describe <cluster> --region <region> --project <service-project> \
  --format="value(monitoringConfig.advancedDatapathObservabilityConfig)"
```

---

## Node pools & compute

The `gke` module can stand up **three sources of capacity**:

| Source | Type | Purpose | Status |
|---|---|---|---|
| `system` node pool | On-demand | System-critical components; never Spot | Always on (`system_node_count`) |
| `default` node pool | Spot | General / burst workloads | **Optional — disabled in dev & prod** |
| NAP / Compute Classes | Mixed | Auto-provisions nodes for unschedulable pods | On (within `nap_*` limits) |

The **`default` Spot pool is gated** by `default_pool_enabled`
(`count = var.default_pool_enabled ? 1 : 0` in `modules/gke/main.tf`). It is **currently
`false` in both `dev/gke.auto.tfvars` and `prod/gke.auto.tfvars`**, so the cluster runs on
the on-demand `system` pool plus NAP-provisioned nodes only. The resource stays in the
module — to bring the pool back, flip the flag to `true` and `apply` (no module edits).

> Removing it is a `0 to add, 0 to change, 1 to destroy` plan (just the
> `it-<env>-cluster-default` pool); the cluster and `system` pool are untouched, so the
> cluster never drops to zero nodes.

Spot vs on-demand for **NAP** nodes is chosen **per ComputeClass**
(`compute-class.yaml`, `priorities[].spot`), not globally.

---

## Deploy

```bash
cd terraform/dev          # or terraform/prod

# 1. edit network.auto.tfvars + gke.auto.tfvars (projects, CIDRs, authorized nets)
# 2. init against the env's GCS state prefix
terraform init

# 3. validate + review a plan ARTIFACT (never blind-apply)
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan

# 4. apply the reviewed artifact only
terraform apply tfplan

# connect (output prints the exact command)
$(terraform output -raw get_credentials_command)
```

`compute-class.yaml` is a Kubernetes resource — deploy it via **ArgoCD**
(no manual `kubectl apply` in prod).

---

## Running dev AND prod on the SAME two projects

> This is the open design decision in this repo. Read before applying both envs.

Separate state files are **not enough** to run both envs in one pair of projects,
because four resources are **project-level singletons** — there is exactly one in
GCP no matter how many state files you keep:

| Singleton | Why only one |
|---|---|
| `google_compute_shared_vpc_host_project` | a project is a Shared-VPC host or not (one flag) |
| `google_compute_shared_vpc_service_project` | a service project attaches to exactly one host |
| `google_project_service_identity` (GKE robot) | one robot per service project |
| `google_project_service` (enabled APIs) | an API is enabled once per project |

Everything else (VPC, subnets, NAT, firewall, cluster, node pool, node SA) is named
`it-<env>-*` → distinct objects → no conflict. Only the four switches collide if both
envs' configs try to create them.

**Two ways to resolve it (not yet implemented):**

- **(A) Shared bootstrap layer (true independence).** Add `terraform/shared/` with its
  own state that owns the four singletons; `dev/` and `prod/` create only their own
  `it-<env>-*` resources and consume the shared foundation. Destroying one env never
  affects the other. Requires a one-time, non-destructive state move of the singletons
  out of an env's state (`terraform state rm` + `terraform import`).
- **(B) `manage_shared_project` flag (simpler).** One env (e.g. prod) owns the four
  singletons; the other sets a flag to `false` and reuses them. No state surgery, but
  the consumer env depends on the owner env's existence.

Until one of these is in place, **dev and prod must use different projects.**
> NOTE: set `dev/network.auto.tfvars` and `prod/network.auto.tfvars` to **separate**
> host/service projects (the committed values are placeholders like
> `my-host-project-dev`), or adopt (A)/(B), before `terraform apply`.

---

## Single-node tuning (how prod was reduced to exactly one node)

Getting a regional cluster down to **one node** took three coordinated settings —
each was a real blocker:

1. `system_node_count = 1` + `system_pool_single_zone = true` → one node, pinned to
   the first discovered zone.
2. **NAP minimum floor → 0** (`nap_cpu_min` / `nap_memory_min` default `0` in
   `modules/gke`). A non-zero floor (e.g. 4 vCPU / 16 GB) forces NAP to provision a
   second node just to satisfy the minimum.
3. `node_machine_type` large enough to fit system pods. `e2-medium` (4 GB) **cannot**
   hold Dataplane V2 + Managed Prometheus + CoreDNS + metadata/logging on one node, so
   NAP keeps a burst node. `e2-standard-2` (8 GB) fits them and the burst node drains.

Verify:
```bash
kubectl get nodes                       # expect 1 Ready node
kubectl get pods -A --field-selector status.phase=Pending   # expect none
```

---

## Key module inputs

| Module | Notable inputs (✦ = has a default) |
|---|---|
| `apis` | `host_apis`✦, `service_apis`✦ |
| `network` | `host_project_id`, `service_project_id`, `region`, `network_name`, `subnet_definitions`, `proxy_subnet_name`, `proxy_subnet_cidr`, `master_ipv4_cidr_block`, `pods_range_name`✦, `services_range_name`✦ |
| `iam` | `host_project_id`, `service_project_id`, `cluster_name`, `gke_subnet_name`, `gke_subnet_region`, `node_iam_roles`✦ |
| `gke` | `regional`✦, `node_zone_count`✦, `release_channel`✦, `kubernetes_version`✦(null=channel default), `node_machine_type`, `node_disk_size_gb`, `node_disk_type`✦, `system_node_count`, `system_pool_single_zone`✦, `default_pool_enabled`✦(false), `default_pool_machine_type`✦, `default_pool_min_nodes`✦, `default_pool_max_nodes`✦, `default_pool_taint`✦, `nap_*`✦, `deletion_protection`✦, `master_authorized_networks` |

`subnet_definitions` is sliced to the **first two** entries (`slice(...,0,2)`); the
first is the GKE node subnet (must carry `pods_cidr`/`services_cidr` and equal `region`).

---

## Validation

```bash
terraform fmt -check -recursive && terraform validate
trivy config .          # IaC misconfig scan
checkov -d .            # policy scan
```

---

## Destroy & rollback

```bash
# Destroy an environment (dev or prod)
cd terraform/environments/prod
terraform destroy        # blocked if deletion_protection = true in state
```

- If `deletion_protection = true` in **state**, the cluster destroy is blocked. Set it
  `false` in `gke.auto.tfvars` and `terraform apply` first, then destroy. (GKE's
  `deletion_protection` is a Terraform-only guard — there is no gcloud flag for it.)
- **State is versioned** in GCS — restore a prior generation:
  ```bash
  gcloud storage cp gs://aslam-terraform-bucket/<env>/shared-vpc-gke/default.tfstate#<gen> ./restore.tfstate
  terraform state push restore.tfstate
  ```
- Destroying an env tears down only its GCP resources; the Terraform code is untouched
  and the env can be re-applied at any time. APIs stay enabled
  (`disable_on_destroy = false`).

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Node pool `RUNNING_WITH_ERROR`, 30+ min create | nodes booted but never registered — usually **egress** to Google APIs/registry blocked | check for a **VPC-SC perimeter** / restrictive **org policy**; confirm Cloud NAT is `RUNNING` and `private_ip_google_access=true` |
| `already associated with host project` on apply | a service project is attached to a host by another state | see "Running dev AND prod on the same projects" |
| Extra NAP node won't drain | NAP min floor > one node, or the node machine type can't fit system pods | set `nap_*_min = 0`; bump `node_machine_type` |
| `value for undeclared variable` | tfvars sets a var the env root doesn't declare | add the `variable` block to the env `variables.tf` |
| `Invalid value for variable` on `subnet_definitions` | first subnet's `region` ≠ `var.region`, or missing `pods_cidr`/`services_cidr` | align region / add the secondary CIDRs |

Diagnostic commands for the egress case:
```bash
gcloud access-context-manager perimeters list 2>/dev/null
gcloud resource-manager org-policies list --project <service-project>
gcloud compute routers get-nat-mapping-info <net>-vpc-nat \
  --router <net>-vpc-router --region <region> --project <host-project>
```
If egress is the cause, add Private Google Access routes to `restricted.googleapis.com`
(199.36.153.4/30) + a private DNS zone in the `network` module instead of relying on
public NAT.

---

## Notes & tradeoffs

- A single `google` / `google-beta` provider pair drives both projects; each
  cross-project resource sets `project` explicitly. Modules declare
  `required_providers` only (no provider blocks).
- `gke` uses module-level `depends_on = [module.iam, module.network]` so the cluster
  waits on **all** Shared-VPC IAM bindings + Cloud NAT, not just the subnet/SA it
  references directly.
- Shared-VPC subnet IAM (`compute.networkUser`) is scoped to the GKE subnet, not the
  whole host project (least privilege).
- `enable_private_endpoint = false` keeps a public-but-firewalled control plane so CI
  can reach it; set `true` + run Terraform from a private runner for full isolation.
- `min_master_version` (`kubernetes_version`) is a **floor** — when the release channel
  auto-upgrades above it there is no perpetual plan diff.
- **Gateway API + Dataplane V2 observability** are hardcoded in the shared `gke` module
  (not flag-gated) because both envs want them identically — a single module edit covers
  dev and prod (DRY). Promote them to `var`s only if an env needs to opt out. See
  "Gateway API & Dataplane V2 observability".
