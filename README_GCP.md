# gcp-iac

Infrastructure as Code on GCP using Terragrunt.

## GCP Org & Project Setup

One-time setup to create the management folder, `infra-mgmt` project, and link billing. Run as an org admin.

```text
3es.nz (org)
├── management (folder)
│   └── infra-mgmt (project)  ← automation SA + Terraform state bucket
└── learning (folder)
    ├── iac-01
    └── iac-02
```

```bash
# Org: 3es.nz (762797842350)
# Billing: NZ3ES (012284-9A8CD4-C9DAE0) — linked to a separate Google account
ORG_ID="762797842350"
BILLING_ACCOUNT="012284-9A8CD4-C9DAE0"

# Create management folder under org
gcloud resource-manager folders create \
    --display-name="management" \
    --organization="$ORG_ID"

# List folders to get management folder ID
gcloud resource-manager folders list --organization="$ORG_ID"
# management    organizations/762797842350  585412383275

# Create nz3es-infra-mgmtt project under management folder
gcloud projects create nz3es-infra-mgmt \
    --name="nz3es-infra-mgmt" \
    --folder=585412383275

# Link infra-mgmt project to billing account
gcloud billing projects link nz3es-infra-mgmt \
    --billing-account="$BILLING_ACCOUNT"
```

## Prerequisites (bootstrap)

SA and state bucket live in `nz3es-infra-mgmt`. The SA is granted roles on `iac-01` and `iac-02`.

```bash
MGMT_PROJECT="nz3es-infra-mgmt"
WORKLOAD_PROJECTS=("iac-01" "iac-02")
SA_NAME="nz3es-automation-sa"
SA_EMAIL="${SA_NAME}@${MGMT_PROJECT}.iam.gserviceaccount.com"
REGION="australia-southeast2"
```

- Enable bootstrap APIs on all projects

```bash
for PROJECT_ID in "$MGMT_PROJECT" "${WORKLOAD_PROJECTS[@]}"; do
    gcloud services enable cloudresourcemanager.googleapis.com --project="$PROJECT_ID"
    gcloud services enable config.googleapis.com --project="$PROJECT_ID"
    gcloud services enable cloudquotas.googleapis.com --project="$PROJECT_ID"
    gcloud services enable serviceusage.googleapis.com --project="$PROJECT_ID"
done
```

- Create Terraform state bucket in `nz3es-infra-mgmt`

```bash
gcloud storage buckets create gs://nz3es-state \
    --location="$REGION" \
    --project="$MGMT_PROJECT"
gcloud storage buckets update gs://nz3es-state --versioning
```

- Create automation SA in `nz3es-infra-mgmt`

```bash
gcloud iam service-accounts create "$SA_NAME" \
    --description="SA for automation" \
    --display-name="$SA_NAME" \
    --project="$MGMT_PROJECT"
```

- Create SA key

```bash
gcloud iam service-accounts keys create "${SA_NAME}.json" \
    --iam-account="$SA_EMAIL" \
    --project="$MGMT_PROJECT"
```

- Grant SA access to state bucket

```bash
gcloud storage buckets add-iam-policy-binding gs://nz3es-state \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectAdmin"
```

- Grant SA permission to manage IAM on its own project (`nz3es-infra-mgmt`)
  (required so Terraform can set IAM bindings on service accounts in the management project)

```bash
gcloud projects add-iam-policy-binding "$MGMT_PROJECT" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/iam.serviceAccountAdmin"
```

- Grant required roles on each workload project

```bash
ROLES=(
    "roles/compute.networkAdmin"
    "roles/compute.admin"
    "roles/storage.admin"
    "roles/serviceusage.serviceUsageAdmin"
    "roles/dns.admin"
    "roles/iam.serviceAccountUser"
    "roles/iam.serviceAccountAdmin"
    "roles/memorystore.admin"
    "roles/networkconnectivity.admin"
    "roles/secretmanager.admin"
    "roles/container.clusterAdmin"
    "roles/container.admin"
    "roles/resourcemanager.projectIamAdmin"
    "roles/privateca.admin"
    "roles/cloudsql.admin"
)

for PROJECT_ID in "${WORKLOAD_PROJECTS[@]}"; do
    for ROLE in "${ROLES[@]}"; do
        echo "[$PROJECT_ID] Adding $ROLE"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="$ROLE"
    done
done
```

- Export environment variables before running Terragrunt

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/nz3es-automation-sa.json"
export GCP_PROJECT="nz3es-infra-mgmt"  # project hosting the Terraform state bucket
export GCP_REGION="australia-southeast2"
```

## Folder Structure

```text
root-gcp.hcl                                              # Root config (path parsing, labels, provider)
modules/
  ├── vpc/                                            # VPC with subnets
  ├── dns-zone/                                       # DNS zones (public/private) with records
  ├── memorystore-valkey/                             # Memorystore for Valkey (Redis-compatible)
  ├── gke-private-cluster/                            # GKE private cluster with NAP support
  └── service-account/                                # Generic service account with IAM roles
nz3es/gcp/{env}/{plane}/{project}/{region}/{component}/
  └── terragrunt.hcl
```

Values are auto-parsed from path: `environment`, `plane`, `project`, `region`, `component`

## Modules

### VPC (`modules/vpc`)

Creates a VPC network with multiple subnets.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `name` | string | VPC name |
| `project_id` | string | GCP project ID |
| `subnets` | map(object) | Map of subnets with region and CIDR |

### DNS Zone (`modules/dns-zone`)

Creates public or private DNS zones with records.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `name` | string | Zone name |
| `dns_name` | string | DNS name (e.g., `example.com.`) |
| `visibility` | string | `public` or `private` |
| `private_visibility_networks` | list(string) | Network URLs for private zones |
| `records` | map(object) | DNS records (type, ttl, rrdatas) |

### Memorystore Valkey (`modules/memorystore-valkey`)

Creates a Memorystore for Valkey instance with PSC connectivity.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `instance_id` | string | Instance name |
| `location` | string | GCP region |
| `network` | string | VPC network name |
| `node_type` | string | `SHARED_CORE_NANO`, `HIGHMEM_MEDIUM`, etc. |
| `shard_count` | number | Number of shards |
| `replica_count` | number | Replicas per shard |
| `authorization_mode` | string | `AUTH_DISABLED` or `IAM_AUTH` |
| `transit_encryption_mode` | string | `TRANSIT_ENCRYPTION_DISABLED` or `SERVER_AUTHENTICATION` |
| `engine_configs` | map(string) | Engine configs (e.g., `maxmemory-policy`) |
| `service_connection_policies` | map(object) | PSC connection policies |

### GKE Private Cluster (`modules/gke-private-cluster`)

Creates a GKE private cluster using [terraform-google-modules/kubernetes-engine v43.0](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/43.0.0). Supports manually defined node pools and Node Auto-Provisioning (NAP).

| Input | Type | Description |
| ----- | ---- | ----------- |
| `cluster_name` | string | GKE cluster name |
| `project_id` | string | GCP project ID |
| `region` | string | GCP region |
| `network` | string | VPC network name |
| `subnetwork` | string | Subnet name |
| `ip_range_pods` | string | Secondary range name for pods |
| `ip_range_services` | string | Secondary range name for services |
| `service_account` | string | Custom service account email for nodes |
| `enable_private_nodes` | bool | Enable private nodes (no public IPs) |
| `cluster_autoscaling` | object | NAP configuration (see NAP section below) |
| `node_pools` | list(map) | Manually defined node pools |

### Service Account (`modules/service-account`)

Creates a GCP service account with configurable IAM roles.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `project_id` | string | GCP project ID |
| `name` | string | Service account ID (derived from folder name) |
| `display_name` | string | Display name (defaults to `name`) |
| `roles` | list(string) | IAM roles to grant (required, no default) |

### Node Auto-Provisioning (NAP)

NAP allows GKE to automatically create and delete node pools based on workload requirements, providing autopilot-style scheduling on a Standard cluster.

#### Why NAP is required

Manually defined node pools (e.g. `nz3es-pool` with `e2-medium`) have fixed machine types. When a workload requests resources that don't fit the existing node pool (e.g. a pod requesting 4 vCPUs on `e2-medium` which only has 2 vCPUs), the pod stays in `Pending` state. NAP solves this by automatically provisioning a new node pool with a machine type that fits the workload.

Without NAP, you would need to pre-create node pools for every possible machine type your workloads might need.

#### How NAP works with manual node pools

- **Manual node pools** (e.g. `nz3es-pool`) continue to operate independently with their own autoscaling (`min_count`/`max_count`).
- **NAP resource limits** (`max_cpu_cores`, `max_memory_gb`) are **cluster-wide** and **include** resources from both manually defined and auto-provisioned node pools.
- When a pod cannot be scheduled on existing nodes, NAP creates a new node pool with an appropriate machine type. When those nodes are no longer needed, NAP deletes the node pool automatically.

#### Custom service account for NAP

NAP requires a service account to create nodes. By default it uses the project's default compute service account (`{project-number}-compute@developer.gserviceaccount.com`), which may not exist or may lack permissions. To avoid this, pass a custom service account via `cluster_autoscaling.service_account`:

```hcl
cluster_autoscaling = {
  enabled             = true
  autoscaling_profile = "OPTIMIZE_UTILIZATION"
  max_cpu_cores       = 16
  max_memory_gb       = 64
  gpu_resources       = []
  auto_repair         = true
  auto_upgrade        = true
  enable_default_compute_class = true
  service_account     = dependency.service_account.outputs.email
}
```

#### Resource limits example

With `max_cpu_cores = 16` and `max_memory_gb = 64`, the cluster can use up to 16 vCPUs and 64 GB of memory total. These limits are **cluster-wide** and include resources from both manually defined node pools (e.g. `nz3es-pool`) and auto-provisioned node pools.

## Configuration

### Region Short Names

Defined in `root-gcp.hcl` for subnet naming:

| Region | Short Name |
| -------- | ------------ |
| `australia-southeast1` | `ause1` |
| `australia-southeast2` | `ause2` |
| `us-central1` | `usc1` |
| `us-east1` | `use1` |
| `us-west1` | `usw1` |
| `europe-west1` | `euw1` |
| `asia-southeast1` | `asse1` |
| `global` | `gbl` |

### Labels

Auto-applied labels from path:

```hcl
labels = {
  managed_by  = "atlantis"
  org         = "nz3es"
  environment = "{env}"      # from path
  plane       = "{plane}"    # from path
  project     = "{project}"  # from path
  region      = "{region}"   # from path
  component   = "{component}" # from path
}
```

### Multiple Subnets per Region

Configure in `root-gcp.hcl`:

```hcl
region_subnets = {
  "australia-southeast2" = ["ause2"]           # single subnet
  "us-central1"          = ["usc1-a", "usc1-b"] # multiple subnets
}
```

## Usage

```bash
# Set environment variables
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"
export GCP_PROJECT="iac-01"
export GCP_REGION="australia-southeast2"

# Deploy single module
cd nz3es/gcp/stg/data-plane/iac-01/global/network
terragrunt apply

# Deploy all modules
cd nz3es/gcp/stg/data-plane/iac-01
terragrunt run-all apply
```

## connect cluster

gcloud container clusters get-credentials stg-iac-01-ause2 --region australia-southeast2 --project iac-01

## Billing Model

| Pool Type | Compute Class | Billing Model | VM Type | Cost |
| --------- | ------------- | ------------- | ------- | ---- |
| Manual (`nz3es-pool`) | N/A | Node-based (pay for full VM) | On-demand | Highest |
| NAP | `autopilot` | Pod-based (pay per pod requests) | On-demand | Medium |
| NAP | `autopilot-spot` | Pod-based (pay per pod requests) | Spot (preemptible) | Lowest (~60-91% cheaper) |

- **Node-based billing**: You pay for the entire VM regardless of pod utilisation
- **Pod-based billing**: You only pay for the CPU/memory requested by pods ([docs](https://cloud.google.com/kubernetes-engine/docs/concepts/about-autopilot-mode-standard-clusters))
- **Spot**: GCP can reclaim the VM at any time with ~30s notice — best for fault-tolerant workloads

## Enable compute class

### Namespace level

```bash
# autopilot (on-demand, pod-based billing)
kubectl label namespace <namespace> cloud.google.com/default-compute-class=autopilot --overwrite

# autopilot-spot (spot, pod-based billing — cheapest option)
kubectl label namespace <namespace> cloud.google.com/default-compute-class=autopilot-spot --overwrite

# Verify namespace label
kubectl get namespace <namespace> -o jsonpath='{.metadata.labels}'

# Verify nodeSelector is injected into pods
kubectl -n <namespace> get pods <podname> -o yaml | grep -A1 nodeSelector

# Remove
kubectl label namespace <namespace> cloud.google.com/default-compute-class-
```

Must be a namespace **label**, not annotation. Pods in the namespace will automatically get `nodeSelector` injected — no workload-level changes needed.

### Workload level

If not using namespace-level default, add `nodeSelector` to the pod spec:

```yaml
# autopilot (on-demand)
nodeSelector:
  cloud.google.com/compute-class: "autopilot"

# autopilot-spot (spot — pods can be evicted anytime)
nodeSelector:
  cloud.google.com/compute-class: "autopilot-spot"
```

With `autopilot-spot`, no toleration is needed — GKE handles it automatically. Manual spot pools (`nz3es-spot-pool`) are not required when using the `autopilot-spot` compute class.

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

### Default Compute Class

[Default Compute Class] (<https://docs.cloud.google.com/kubernetes-engine/docs/how-to/run-pods-default-compute-classes>)
<https://docs.cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning>
