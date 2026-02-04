# gcp-iac

Infrastructure as Code on GCP using Terragrunt.

## Folder Structure

```text
root.hcl                                              # Root config (path parsing, labels, provider)
modules/
  ├── vpc/                                            # VPC with subnets
  ├── dns-zone/                                       # DNS zones (public/private) with records
  └── memorystore-valkey/                             # Memorystore for Valkey (Redis-compatible)
nz3es/gcp/{env}/{plane}/{project}/{region}/{component}/
  └── terragrunt.hcl
```

Values are auto-parsed from path: `environment`, `plane`, `project`, `region`, `component`

## Modules

### VPC (`modules/vpc`)

Creates a VPC network with multiple subnets.

| Input | Type | Description |
|-------|------|-------------|
| `name` | string | VPC name |
| `project_id` | string | GCP project ID |
| `subnets` | map(object) | Map of subnets with region and CIDR |

### DNS Zone (`modules/dns-zone`)

Creates public or private DNS zones with records.

| Input | Type | Description |
|-------|------|-------------|
| `name` | string | Zone name |
| `dns_name` | string | DNS name (e.g., `example.com.`) |
| `visibility` | string | `public` or `private` |
| `private_visibility_networks` | list(string) | Network URLs for private zones |
| `records` | map(object) | DNS records (type, ttl, rrdatas) |

### Memorystore Valkey (`modules/memorystore-valkey`)

Creates a Memorystore for Valkey instance with PSC connectivity.

| Input | Type | Description |
|-------|------|-------------|
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

## Configuration

### Region Short Names

Defined in `root.hcl` for subnet naming:

| Region | Short Name |
|--------|------------|
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
    )

    # Loop through each role and assign it
    for ROLE in "${ROLES[@]}"; do
        echo "Adding $ROLE to $MEMBER on project $PROJECT_ID"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$MEMBER" --role="$ROLE"
    done
    ```

  - Additional Roles if required

    ```text
        --role="roles/compute.instanceAdmin.v1"
        --role="roles/container.admin"
        --role="roles/bigquery.admin"
    ```

## Troubleshooting

See [backup/troubleshooting.md](backup/troubleshooting.md) for common issues and solutions.

gcloud container node-pools list --cluster=stg-iac-01 --region=australia-southeast2 --project=iac-01

cd nz3es/gcp/stg/data-plane/iac-01/australia-southeast2/gke/stg-iac-01

terragrunt import 'module.gke.google_container_node_pool.pools["default-pool"]' projects/iac-01/locations/australia-southeast2/clusters/stg-iac-01/nodePools/default-pool

gcloud container clusters get-credentials stg-iac-01 --region australia-southeast2 --project iac-01
