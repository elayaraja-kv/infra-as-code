# gcp-iac

Infrastructure as Code on GCP using Terragrunt.

## Folder Structure

```text
root.hcl                                              # Root config (path parsing, labels, provider)
modules/
  ├── vpc/                                            # VPC with subnets
  ├── dns-zone/                                       # DNS zones (public/private) with records
  ├── memorystore-valkey/                             # Memorystore for Valkey (Redis-compatible)
  ├── gke-private-cluster/                            # GKE private cluster with NAP support
  └── gke-service-account/                            # Custom service account for GKE nodes
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

### GKE Service Account (`modules/gke-service-account`)

Creates a custom service account for GKE nodes with the minimum required IAM roles.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `project_id` | string | GCP project ID |
| `name` | string | Service account ID (derived from folder name) |
| `display_name` | string | Display name |
| `roles` | list(string) | IAM roles (defaults: logWriter, metricWriter, monitoring.viewer, stackdriver.resourceMetadata.writer, artifactregistry.reader) |

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

Defined in `root.hcl` for subnet naming:

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

Configure in `root.hcl`:

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

## Prerequisites (bootstrap)

- Enable API

    ```bash
    gcloud services enable cloudresourcemanager.googleapis.com --project=iac-01
    gcloud services enable config.googleapis.com --project=iac-01
    gcloud services enable cloudquotas.googleapis.com --project=iac-01
    ```

- Create a storage account

    ```bash
    gcloud --project=iac-01 storage buckets create gs://nz3es-tf-state-iac --location=australia-southeast2
    ```

- Enable versioning on bucket

    ```bash
    gcloud storage buckets update gs://nz3es-tf-state-iac --enable-versioning
    ```

- Create a service account

    ```bash
    gcloud iam service-accounts create nz3es-automation-sa \
        --description="SA for automation" \
        --display-name="nz3es-automation-sa" \
        --project=iac-01
    ```

- Create a service account key

    ```bash
    gcloud iam service-accounts keys create nz3es-automation-sa-key.json \
        --iam-account=<nz3es-automation-sa@iac-01.iam.gserviceaccount.com> \
        --project=iac-01
    ```

- Enable Infra Manager executes Terraform using the identity of this service account.
  - <https://docs.cloud.google.com/infrastructure-manager/docs/configure-service-account>

    ```bash
    gcloud projects add-iam-policy-binding iac-01 \
        --member="serviceAccount:nz3es-automation-sa@iac-01.iam.gserviceaccount.com" \
        --role="roles/config.agent" \
        --project=iac-01
    ```

- Adding required roles to the service account

    ```bash
    #!/bin/bash

    # Define variables
    # assign "roles/owner" or else assign below roles
    PROJECT_ID="iac-01"
    MEMBER="serviceAccount:nz3es-automation-sa@iac-01.iam.gserviceaccount.com"
    ROLES=(
        "roles/compute.networkAdmin"
        "roles/storage.admin"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/dns.admin"
        "roles/iam.serviceAccountUser"
        "roles/memorystore.admin"
        "roles/networkconnectivity.admin"
        "roles/secretmanager.admin"
        "roles/container.clusterAdmin"
        "roles/container.admin"
        "roles/iam.serviceAccountAdmin"
        "roles/resourcemanager.projectIamAdmin"
    )

    # Loop through each role and assign it
    for ROLE in "${ROLES[@]}"; do
        echo "Adding $ROLE to $MEMBER on project $PROJECT_ID"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$MEMBER" --role="$ROLE"
    done
    ```

## connect cluster

gcloud container clusters get-credentials stg-iac-01 --region australia-southeast2 --project iac-01

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

### Default Compute Class

[Default Compute Class] (<https://docs.cloud.google.com/kubernetes-engine/docs/how-to/run-pods-default-compute-classes>)
<https://docs.cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning>
