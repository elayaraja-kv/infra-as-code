# gcp-iac

Infrastructure as Code on GCP

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
    gcloud projects add-iam-policy-binding iac-01 \
        --member="serviceAccount:nz3es-automation-sa@iac-01.iam.gserviceaccount.com" \
        --role="roles/compute.networkAdmin" \
        --project=iac-01
    ```

  - Additional Roles

    ```text
        --role="roles/compute.instanceAdmin.v1"
        --role="roles/iam.serviceAccountUser"
        --role="roles/container.admin"
        --role="roles/bigquery.admin"
        --role="roles/storage.admin"
        --role="roles/serviceusage.serviceUsageAdmin"
    ```
