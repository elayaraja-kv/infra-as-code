# infra-as-code

Infrastructure as Code using Terragrunt — multi-cloud.

## Providers

| Provider | README | Root config | Deployment path |
| -------- | ------ | ----------- | --------------- |
| GCP | [README_GCP.md](README_GCP.md) | `root-gcp.hcl` | `nz3es/gcp/{env}/...` |
| Azure | [README_Azure.md](README_Azure.md) | `root-azure.hcl` | `nz3es/azure/{env}/...` |

## Path Convention

All deployment units follow the same structure regardless of provider:

```text
{org}/{provider}/{env}/{plane}/{project}/{region}/{component}/
  └── terragrunt.hcl
```

Example:

```text
nz3es/gcp/stg/data-plane/iac-01/australia-southeast2/gke/stg-iac-01/
nz3es/azure/stg/data-plane/iac-01/australiaeast/aks/stg-iac-01/
```

## Modules

```text
modules/
  ├── gcp/          # GCP-specific modules (see README_GCP.md)
  └── azure/        # Azure-specific modules (see README_Azure.md)
```
