# azure-iac

Infrastructure as Code on Azure using Terragrunt.

## Prerequisites (bootstrap)

Run once before first `terragrunt apply`. These steps create the state backend and the automation identity.

- **Install Azure CLI**

    ```bash
    brew install azure-cli    # macOS
    az login
    ```

- **Set variables**

    ```bash
    SUBSCRIPTION_ID="009882d7-c336-42a0-8f65-bfea9e52d9c1"
    TENANT_ID="89521795-6a41-4e41-96a5-cde8b33f6f35"
    LOCATION="australiaeast"
    STATE_RG="nz3es-tf-state-rg"
    STATE_SA="nz3estfstate"           # must be globally unique, 3-24 lowercase alphanumeric
    STATE_CONTAINER="tfstate"
    SP_NAME="nz3es-automation-sp"
    ```

- **Create resource group for Terraform state**

    ```bash
    az group create \
      --name "$STATE_RG" \
      --location "$LOCATION" \
      --subscription "$SUBSCRIPTION_ID"
    ```

- **Create storage account and container for Terraform state**

    ```bash
    az storage account create \
      --name "$STATE_SA" \
      --resource-group "$STATE_RG" \
      --location "$LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --allow-blob-public-access false \
      --subscription "$SUBSCRIPTION_ID"

    az storage container create \
      --name "$STATE_CONTAINER" \
      --account-name "$STATE_SA" \
      --subscription "$SUBSCRIPTION_ID"
    ```

- **Enable versioning on the storage account** (equivalent to GCS bucket versioning)

    ```bash
    az storage account blob-service-properties update \
      --account-name "$STATE_SA" \
      --resource-group "$STATE_RG" \
      --enable-versioning true \
      --subscription "$SUBSCRIPTION_ID"
    ```

- **Create a service principal for automation**

    ```bash
    SP=$(az ad sp create-for-rbac \
      --name "$SP_NAME" \
      --skip-assignment \
      --output json)

    SP_APP_ID=$(echo "$SP" | jq -r '.appId')         # ARM_CLIENT_ID
    SP_SECRET=$(echo "$SP" | jq -r '.password')       # ARM_CLIENT_SECRET
    # ARM_TENANT_ID is already set above as $TENANT_ID

    echo "appId (ARM_CLIENT_ID):     $SP_APP_ID"
    echo "password (ARM_CLIENT_SECRET): $SP_SECRET"
    ```

    > `jq` is required (`brew install jq`). Keep `$SP_SECRET` — it is shown only once and cannot be retrieved later.

- **Assign required RBAC roles to the service principal**

    ```bash
    #!/bin/bash

    SP_OBJECT_ID=$(az ad sp show --id "$SP_APP_ID" --query id -o tsv)
    SCOPE="/subscriptions/$SUBSCRIPTION_ID"

    ROLES=(
      "Contributor"                           # create/manage most resources
      "User Access Administrator"             # assign roles to managed identities
      "Private DNS Zone Contributor"          # manage private DNS zones for AKS private endpoint
      "Network Contributor"                   # manage VNets, NSGs, route tables
      "Storage Blob Data Contributor"         # read/write Terraform state blobs
      "Key Vault Administrator"               # manage Key Vault (if used)
    )

    for ROLE in "${ROLES[@]}"; do
      echo "Assigning: $ROLE"
      az role assignment create \
        --assignee-object-id "$SP_OBJECT_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "$ROLE" \
        --scope "$SCOPE" \
        --subscription "$SUBSCRIPTION_ID"
    done
    ```

    > `User Access Administrator` is needed so Terraform can assign roles to the AKS managed identity (e.g. `Network Contributor` on the subnet). Scope it to the specific subscription or resource group rather than the whole tenant if preferred.

- **Export environment variables for Terragrunt**

    ```bash
    export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
    export ARM_TENANT_ID="$TENANT_ID"
    export ARM_CLIENT_ID="$SP_APP_ID"
    export ARM_CLIENT_SECRET="$SP_SECRET"
    export TF_STATE_RESOURCE_GROUP="$STATE_RG"
    export TF_STATE_STORAGE_ACCOUNT="$STATE_SA"
    ```

## Folder Structure

```text
root-azure.hcl                                          # Root config (path parsing, tags, azurerm backend + provider)
modules/
  ├── azure/resource-group/                             # Resource group
  ├── azure/network/                                    # VNet with subnets, NSGs, service endpoints
  ├── azure/nat-gateway/                                # NAT gateway + public IP for private node outbound
  ├── azure/aks-cluster/                                # AKS cluster (Option B: public endpoint + IP whitelist; snet-aks-apiserver reserved for Option D upgrade)
  └── azure/managed-identity/                           # User-assigned managed identity + role assignments + federated credentials
nz3es/azure/{env}/{plane}/{project}/{region}/{component}/
  └── terragrunt.hcl
```

Values are auto-parsed from path: `environment`, `plane`, `project`, `region`, `component`

## Modules

### Resource Group (`modules/azure/resource-group`)

Creates an Azure resource group.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `name` | string | Resource group name |
| `location` | string | Azure region |
| `tags` | map(string) | Tags to apply |

**Outputs:** `name`, `id`, `location`

### Network (`modules/azure/network`)

Creates a VNet with subnets using [Azure/vnet/azurerm](https://registry.terraform.io/modules/Azure/vnet/azurerm).

| Input | Type | Description |
| ----- | ---- | ----------- |
| `resource_group_name` | string | Resource group to deploy into |
| `vnet_location` | string | Azure region |
| `vnet_name` | string | VNet name |
| `address_space` | list(string) | VNet CIDR(s) |
| `subnet_names` | list(string) | Subnet names |
| `subnet_prefixes` | list(string) | Subnet CIDRs (same order as names) |
| `subnet_delegation` | map(object) | Service delegations per subnet (e.g. AKS) |
| `subnet_service_endpoints` | map(list) | Service endpoints per subnet |
| `tags` | map(string) | Tags to apply |

**Outputs:** `vnet_id`, `vnet_name`, `vnet_subnets` (list of subnet IDs), `vnet_subnets_name_id` (map of name → subnet ID — use this for lookups)

### NAT Gateway (`modules/azure/nat-gateway`)

Creates a NAT gateway with a static public IP and attaches it to one or more subnets. Required to give private AKS nodes outbound internet access (image pulls, Helm repo downloads, etc.) when nodes have no public IPs.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `resource_group_name` | string | Resource group to deploy into |
| `location` | string | Azure region |
| `name` | string | CAF name for the NAT gateway (`ng-` prefix) |
| `public_ip_name` | string | CAF name for the public IP (`pip-` prefix) |
| `subnet_ids` | list(string) | Subnet IDs to attach the NAT gateway to |
| `zones` | list(string) | Availability zones for the public IP (default: `["1"]`) |
| `tags` | map(string) | Tags to apply |

**Outputs:** `nat_gateway_id`, `public_ip_address`, `public_ip_id`

### AKS Cluster (`modules/azure/aks-cluster`)

Creates an AKS cluster (Option B: public endpoint + IP whitelist) using [Azure/aks/azurerm v9.1.0](https://registry.terraform.io/modules/Azure/aks/azurerm). Option D (VNet integration) requires v10+ — see [Upgrading from Option B to Option D](#upgrading-from-option-b-to-option-d).

| Input | Type | Description |
| ----- | ---- | ----------- |
| `resource_group_name` | string | Resource group to deploy into |
| `location` | string | Azure region |
| `cluster_name` | string | AKS cluster name |
| `vnet_subnet_id` | string | Subnet resource ID for the system node pool (`snet-aks-nodes`) |
| `api_server_authorized_ip_ranges` | list(string) | CIDRs allowed to reach the public API endpoint |
| `kubernetes_version` | string | Kubernetes minor version (e.g. `"1.31"`) |
| `agents_vm_size` | string | VM size for the system node pool |
| `agents_min_count` | number | Min nodes in system pool (auto-scaling) |
| `agents_max_count` | number | Max nodes in system pool |
| `identity_ids` | list(string) | Resource IDs of user-assigned managed identities |
| `node_pools` | map(object) | Additional user node pools |
| `rbac_aad_admin_group_object_ids` | list(string) | AAD group object IDs with cluster admin access |
| `tags` | map(string) | Tags to apply |

**Outputs:** `cluster_id`, `cluster_name`, `kube_config_raw`, `host`, `oidc_issuer_url` (for Workload Identity)

### Managed Identity (`modules/azure/managed-identity`)

Creates a user-assigned managed identity with optional role assignments and Workload Identity federated credentials.

| Input | Type | Description |
| ----- | ---- | ----------- |
| `resource_group_name` | string | Resource group to deploy into |
| `location` | string | Azure region |
| `name` | string | Identity name (derived from folder name) |
| `tags` | map(string) | Tags to apply |
| `role_assignments` | list(object) | `{ scope, role_definition_name }` pairs |
| `federated_credentials` | list(object) | OIDC federated credentials for Workload Identity |

**Outputs:** `id`, `principal_id`, `client_id`, `name`

## Workload Identity Pattern

Mirrors the GCP Workload Identity pattern — infra-as-code creates the identity; k8s-as-code annotates the KSA.

**infra-as-code** (`managed-identity` unit):

```hcl
federated_credentials = [{
  name    = "external-dns"
  issuer  = dependency.aks.outputs.oidc_issuer_url
  subject = "system:serviceaccount:external-dns:external-dns"
}]
```

**k8s-as-code** (Helm `values-stg.yaml`):

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<client-id from managed-identity output>"
```

The pod also needs the label `azure.workload.identity/use: "true"` and the cluster must have `oidc_issuer_enabled = true` (set in the module defaults).

## Configuration

### Region Short Names

Defined in `root-azure.hcl`:

| Region | Short Name |
| ------ | ---------- |
| `australiaeast` | `ause` |
| `australiasoutheast` | `ause2` |
| `australiacentral` | `ausc` |
| `eastus` | `use` |
| `eastus2` | `use2` |
| `westus` | `usw` |
| `westus2` | `usw2` |
| `westeurope` | `euw` |
| `northeurope` | `eun` |
| `southeastasia` | `asse` |
| `eastasia` | `ase` |
| `global` | `gbl` |

### Tags

Auto-applied tags from path:

```hcl
tags = {
  org         = "nz3es"
  environment = "{env}"
  plane       = "{plane}"
  project     = "{project}"
  region      = "{region}"
  component   = "{component}"
  managed_by  = "terragrunt"
}
```

### CAF Naming Convention

All Azure resources follow [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) naming. Pattern: `{type}-{workload}-{env}-{project}-{region_short}`

Abbreviation as **prefix** so resources sort by type in the Azure portal.

| Resource | Abbreviation | Example |
| -------- | ------------ | ------- |
| Resource group | `rg` | `rg-aks-stg-iac-01-ause` |
| Virtual network | `vnet` | `vnet-stg-iac-01-ause` |
| Subnet | `snet` | `snet-aks-nodes` |
| AKS cluster | `aks` | `aks-stg-iac-01-ause` |
| Managed identity | `id` | `id-aks-cluster-stg-iac-01-ause` |
| Key vault | `kv` | `kv-stg-iac-01-ause` |
| Storage account | `st` | `ststgiac01ause` (no hyphens, max 24 chars) |
| Container registry | `cr` | `cr-stg-iac-01-ause` |
| Private endpoint | `pep` | `pep-stg-iac-01-ause` |

Folder names never contain env or region — derived at runtime from root locals:

```hcl
# folder: resource-group/aks/
name = "rg-${basename(get_terragrunt_dir())}-${include.root.locals.environment}-${include.root.locals.project}-${include.root.locals.region_short}"
# → rg-aks-stg-iac-01-ause
```

### Resource Group Design

Units under `global/` (e.g. managed identities) are logically cross-regional but still live in the regional resource group — Azure has no truly global resource scope unlike GCP.

## Control Plane Access Options

AKS gives four ways to secure the Kubernetes API server. The current deployment uses **Option B** (staging). `snet-aks-apiserver` is reserved for a future upgrade to **Option D** when the module is upgraded to v10+.

### Option A — Public cluster (unrestricted)

- API server reachable from any IP on the internet.
- Simplest setup; suitable only for dev/sandbox with strong AAD RBAC.
- **Not recommended** for production.

### Option B — Public cluster with IP whitelist (current — staging)

- API server publicly accessible but firewalled to specific CIDRs.
- Set `api_server_authorized_ip_ranges` to office/VPN/CI egress IPs.
- No VNet subnet needed for the API server.
- Simple, no VNet peering required; works well for small teams.

### Option C — Fully private cluster

- API server has no public endpoint; accessible only from within the VNet or peered networks.
- Requires a jump VM or VPN to run `kubectl` or `terragrunt apply`.
- `az aks command invoke` is available as an escape hatch (executes commands server-side).
- Most secure option; highest operational overhead.

### Option D — VNet-integrated API server + IP whitelist

- API server NIC is injected into `snet-aks-apiserver` (`/28` min, delegated to `Microsoft.ContainerService/managedClusters`).
- Public endpoint remains enabled but restricted to `api_server_authorized_ip_ranges`.
- Node-to-API-server traffic stays entirely within the VNet (no public internet hop, lower latency).
- Best balance of security and operational simplicity for production.
- **Requires `Azure/aks/azurerm` v10+** — the `api_server_vnet_integration_enabled` variable does not exist in v9.x.

#### Upgrading from Option B to Option D

1. **Bump module version** in `modules/azure/aks-cluster/terragrunt.hcl`:

   ```hcl
   terraform {
     source = "tfr:///Azure/aks/azurerm?version=10.x.x"  # check registry for latest v10
   }
   ```

   Review the v9 → v10 changelog for breaking variable renames before applying.

2. **Add VNet integration flag** to `modules/azure/aks-cluster/terragrunt.hcl` wrapper inputs:

   ```hcl
   api_server_vnet_integration_enabled = true
   ```

3. **Add subnet reference** to the deployment unit `inputs`:

   ```hcl
   api_server_subnet_id = dependency.network.outputs.vnet_subnets_name_id["snet-aks-apiserver"]
   ```

   The `snet-aks-apiserver` subnet (`10.1.3.0/28`) is already provisioned and delegated — no network changes needed.

4. **Re-apply AKS** — Azure will update the cluster in-place (this is a control plane change, no node drain needed):

   ```bash
   terragrunt apply --working-dir nz3es/azure/stg/data-plane/iac-01/australiaeast/aks/stg-iac-01
   ```

**VNet layout:**

```text
VNet 10.1.0.0/22
  snet-aks-nodes       10.1.0.0/24    256 IPs  — AKS nodes (NAT gateway attached)
  snet-private-ep      10.1.1.0/27     32 IPs  — Private endpoints (Key Vault, ACR, etc.)
  spare                10.1.2.0/24    256 IPs  — Future node pool or workload subnet
  snet-aks-apiserver   10.1.3.0/28     16 IPs  — API server VNet integration (delegated)
  unallocated          10.1.3.16+             — Future subnets within this block
```

**Env var for IP whitelist:**

```bash
export AKS_API_SERVER_AUTHORIZED_IPS="203.0.113.10/32 198.51.100.0/24"
```

> Set to your workstation/VPN/CI egress IPs. Empty string = public endpoint effectively blocked (all non-VNet access denied).

## Usage

```bash
# Set environment variables
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export ARM_TENANT_ID="<your-tenant-id>"

# Auth — choose one:
az login                                    # interactive (local dev)
export ARM_CLIENT_ID="..."                  # service principal (CI)
export ARM_CLIENT_SECRET="..."

# Deploy a single unit
terragrunt apply --working-dir nz3es/azure/stg/data-plane/iac-01/australiaeast/network

# Deploy all units under an environment (Terragrunt resolves dependency order automatically)
terragrunt run-all apply --working-dir nz3es/azure/stg/data-plane/iac-01
```

## Deployment Order (first deploy)

Units must be applied in dependency order. Apply each with:
`terragrunt apply --working-dir <path>`

```text
Step  Path                                                                              Depends on
────  ────────────────────────────────────────────────────────────────────────────────  ──────────────────────────────────────
1     nz3es/azure/stg/data-plane/iac-01/australiaeast/resource-group/network           —
2     nz3es/azure/stg/data-plane/iac-01/australiaeast/resource-group/aks               —
3     nz3es/azure/stg/data-plane/iac-01/australiaeast/network                          step 1
4     nz3es/azure/stg/data-plane/iac-01/australiaeast/nat-gateway                      steps 1, 3
5     nz3es/azure/stg/data-plane/iac-01/global/iam/managed-identities/aks-cluster      steps 2, 3
6     nz3es/azure/stg/data-plane/iac-01/australiaeast/aks/stg-iac-01                   steps 2, 3, 4, 5
```

> Steps 1 and 2 can be applied in parallel. Steps 4 and 5 can be applied in parallel once steps 1–3 are done.

### Required env vars for step 6 (AKS cluster)

Set these before applying the AKS unit:

```bash
# AAD group whose members get cluster-admin access.
# REQUIRED — local_account_disabled = true locks everyone out until this is set.
# Get the object ID: az ad group show --group "AKS Administrators" --query id -o tsv
export AKS_ADMIN_GROUP_ID="<aad-group-object-id>"

# CIDRs allowed to reach the public API endpoint (Option B).
# Space-separated. Empty = no public access (use az aks command invoke instead).
export AKS_API_SERVER_AUTHORIZED_IPS="203.0.113.10/32 198.51.100.0/24"
```

## Connect to cluster

The cluster uses Option B (public endpoint + IP whitelist). Ensure your IP is in `AKS_API_SERVER_AUTHORIZED_IPS` before applying, then connect normally:

```bash
az aks get-credentials \
  --resource-group rg-aks-stg-iac-01-ause \
  --name aks-stg-iac-01-ause \
  --subscription "$SUBSCRIPTION_ID"

kubectl get nodes
```

If your IP is not whitelisted, use `az aks command invoke` as an escape hatch (executes server-side within the VNet):

```bash
az aks command invoke \
  --resource-group rg-aks-stg-iac-01-ause \
  --name aks-stg-iac-01-ause \
  --command "kubectl get nodes"
```

## Node Outbound Internet Options

Private AKS nodes have no public IPs, so outbound internet (image pulls, Helm repo downloads, etc.) requires an explicit egress path. Two main options:

### Option 1 — NAT Gateway (current)

A NAT gateway is attached to `snet-aks-nodes`. All outbound traffic is SNATted through a static public IP — no filtering, low cost, low complexity.

| Attribute | Value |
| --------- | ----- |
| Cost | ~$35/month + data transfer |
| Outbound control | None — all traffic passes |
| Inbound | Not supported |
| Complexity | Low |

**When to use:** Non-production, cost-sensitive, or when outbound control is handled at another layer (network policy, OPA).

### Option 2 — Azure Firewall (enterprise prod)

A central Azure Firewall in a hub VNet inspects all outbound traffic. A User Defined Route (UDR) on `snet-aks-nodes` forces `0.0.0.0/0` through the Firewall private IP via VNet peering.

| Attribute | Value |
| --------- | ----- |
| Cost | ~$900/month (Standard) / ~$1,400/month (Premium) + data |
| Outbound control | FQDN/IP allowlist, TLS inspection, threat intel feed |
| Inbound | Supported via DNAT rules |
| Complexity | High — rule maintenance + UDRs required |

**When to use:** Regulated/production environments requiring egress audit logs or FQDN-level allowlisting. AKS publishes a [required FQDN list](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress) for Firewall application rules.

**Hub-spoke topology:**

```text
Hub VNet
  └── Azure Firewall (shared across all spokes)

Spoke VNet (this AKS VNet)
  └── UDR on snet-aks-nodes: 0.0.0.0/0 → Firewall private IP (via VNet peering)
```

> NAT Gateway and Azure Firewall are **mutually exclusive** on the same subnet. Remove the NAT Gateway association before attaching a Firewall UDR.

### Switching from NAT Gateway to Azure Firewall

1. Remove NAT gateway from `australiaeast/nat-gateway/terragrunt.hcl` (or remove the `snet-aks-nodes` association)
2. Create a UDR resource pointing `0.0.0.0/0` to the Firewall private IP
3. Set `route_tables_ids = { "snet-aks-nodes" = "<udr-id>" }` in the network unit — the module wrapper already exposes this input

## Add-ons

### Required add-ons (always enabled)

| Add-on | Variable | Purpose |
| ------ | -------- | ------- |
| OIDC Issuer | `oidc_issuer_enabled` | Exposes the OIDC discovery endpoint; prerequisite for Workload Identity — `oidc_issuer_url` output is empty without it |
| Workload Identity | `workload_identity_enabled` | Webhook that injects token volumes into pods so they can exchange KSA tokens for Azure AD tokens |
| Key Vault Secrets Provider | `key_vault_secrets_provider_enabled` | CSI driver for mounting Key Vault secrets/certs as volumes |

### Optional add-ons (disabled by default)

| Add-on | Variable | Notes |
| ------ | -------- | ----- |
| Azure Policy | `azure_policy_enabled` | OPA Gatekeeper for policy enforcement; adds a DaemonSet (~100m CPU / 200Mi per node) |
| Container Insights | `oms_agent_enabled` | Log Analytics monitoring; costs per GB ingested — skip if using Prometheus/Grafana |
| Microsoft Defender | `microsoft_defender_enabled` | Runtime threat detection; additional cost |
| Image Cleaner | `image_cleaner_enabled` | Removes unused images from nodes to reclaim disk |
| Web App Routing | `web_app_routing_enabled` | Managed NGINX ingress + Azure DNS integration |
| HTTP Application Routing | `http_application_routing_enabled` | **Deprecated** — do not use |
| Open Service Mesh | `open_service_mesh_enabled` | **Deprecated** — do not use |

### Useful CLI commands

```bash
# List all available addon names
az aks addon list-available -o table

# List addon status on a running cluster
az aks addon list \
  --resource-group rg-aks-stg-iac-01-ause \
  --name aks-stg-iac-01-ause \
  -o table
```

## Node Pool Billing Model

| Pool | Priority | Billing | Use case |
| ---- | -------- | ------- | -------- |
| `system` | On-demand | Node-based (full VM) | System components (kube-system) |
| `workload` | On-demand | Node-based (full VM) | General workloads |
| `spot` | Spot | Node-based at spot price (~60-80% cheaper) | Fault-tolerant, batch workloads |

Azure does not have pod-based billing equivalent to GKE Autopilot compute classes. All AKS pools are node-based.

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.
