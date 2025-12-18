# Infrastructure Prerequisites & Deployment Guide

This document details the infrastructure requirements and steps to deploy the solution to Google Cloud. You can also go ahead with the automated Terraform setup, which will create all the required resources. You only need to loging with your gcloud sdk, set terraform variables terraform.tfvars and run `terraform apply`.

## 1. Initial Setup & Authentication

Ensure you have the Google Cloud SDK (`gcloud`) installed.

1.  **Login to Google Cloud:**
    ```bash
    gcloud auth login
    ```
2.  **Set your Project ID:**
    ```bash
    gcloud config set project YOUR_PROJECT_ID
    ```
3.  **Set your Region:**
    ```bash
    gcloud config set compute/region europe-west1
    ```

## 2. Enable Required Services

Enable the necessary Google Cloud APIs for the project:

```bash
gcloud services enable \
    alloydb.googleapis.com \
    compute.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    aiplatform.googleapis.com \
    discoveryengine.googleapis.com \
    servicenetworking.googleapis.com \
    servicenetworking.googleapis.com \
    cloudresourcemanager.googleapis.com
```

## 3. Storage (GCS)
Terraform creates a GCS bucket for storing property images.
- **Bucket Name**: `property-images-YOUR_PROJECT_ID`
- **Access**: Private (Service Account `roles/storage.objectAdmin`)



## 4. Networking (Private Service Access)

AlloyDB requires a private IP range for VPC peering.

```bash
# 1. Create a private IP range
gcloud compute addresses create alloydb-private-ip \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --description="Private IP Range for AlloyDB" \
    --network=default

# 2. Create the private connection
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=alloydb-private-ip \
    --network=default \
    --project=YOUR_PROJECT_ID
```

## 5. AlloyDB Configuration

The solution requires an AlloyDB cluster with specific flags enabled for AI capabilities.

### Cluster & Instance Details
-   **Cluster ID**: `hr-dev` (example)
-   **Instance ID**: `hr-primary` (example)
-   **Region**: `europe-west1`
-   **Machine Type**: `db-standard-2` (2 vCPUs, 16GB RAM)
-   **Public IP**: Enabled (Required for local development/demos without VPN)

### Required Database Flags
The following flags **MUST** be set on the primary instance for the AI features to work:
-   `alloydb_ai_nl.enabled=on`
-   `google_ml_integration.enable_ai_query_engine=on`
-   `scann.enable_zero_knob_index_creation=on`
-   `password.enforce_complexity=on`
-   `google_db_advisor.enable_auto_advisor=on`
-   `google_db_advisor.auto_advisor_schedule='EVERY 24 HOURS'`

### Creation Commands

**1. Create the Cluster:**
```bash
gcloud alloydb clusters create hr-dev \
    --region=europe-west1 \
    --password=YOUR_DB_PASSWORD
```

**2. Create the Primary Instance:**
```bash
gcloud alloydb instances create hr-primary \
    --cluster=hr-dev \
    --region=europe-west1 \
    --cpu-count=2 \
    --ssl-mode=ENCRYPTED_ONLY \
    --assign-ip \
    --database-flags="alloydb_ai_nl.enabled=on,google_ml_integration.enable_ai_query_engine=on,scann.enable_zero_knob_index_creation=on,password.enforce_complexity=on,google_db_advisor.enable_auto_advisor=on,google_db_advisor.auto_advisor_schedule='EVERY 24 HOURS'"
```
*Note: `--assign-ip` enables the Public IP.*

## 6. IAM & Permissions

### User (Deployer) Permissions
The user running the deployment (`deploy.sh`) needs the following roles:
-   `roles/owner` OR `roles/editor` (for broad access)
-   OR Granular:
    -   `roles/artifactregistry.writer`
    -   `roles/run.admin`
    -   `roles/iam.serviceAccountUser`
    -   `roles/alloydb.admin`

### Service Account Permissions
The Cloud Run service uses a Service Account (often the default Compute Engine SA: `[PROJECT_NUMBER]-compute@developer.gserviceaccount.com`).

It requires the following roles to function correctly:

| Role | Purpose |
| :--- | :--- |
| `roles/alloydb.client` | Connect to AlloyDB via Auth Proxy |
| `roles/logging.logWriter` | Write logs to Cloud Logging |
| `roles/artifactregistry.repoAdmin` | Manage container images |
| `roles/serviceusage.serviceUsageConsumer` | Consume Google Cloud APIs |
| `roles/aiplatform.user` | Access Vertex AI (Embeddings, LLMs) |
| `roles/discoveryengine.editor` | Access Vertex AI Search (Data Stores) |

**Command to grant roles to the Service Account:**
```bash
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/alloydb.client"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/logging.logWriter"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/artifactregistry.repoAdmin"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/serviceusage.serviceUsageConsumer"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/aiplatform.user"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/discoveryengine.editor"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/discoveryengine.editor"
```

### AlloyDB Service Agent Permissions
To use Vertex AI integration (embeddings), the AlloyDB Service Agent must have the `roles/aiplatform.user` role.

```bash
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
ALLOYDB_SA="service-${PROJECT_NUMBER}@gcp-sa-alloydb.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$ALLOYDB_SA" \
    --role="roles/aiplatform.user"
```

## 7. Vertex AI Search (Data Store Creation)

Go to Vertex AI Search, add a new App and link it to your AlloyDB table (Preview feature). After import make sure to set in the schema settings that all collumns are searchable and retrievable.

### Create Data Store with AlloyDB Source
This command creates a new Data Store and links it to your AlloyDB table.

Below the http curl command to create it via API instead of the UI.

**Prerequisites:**
-   The AlloyDB instance must be reachable.
-   The user/service account running this must have `roles/discoveryengine.admin` or similar.

```bash
# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="europe-west1" # AlloyDB Region
DATA_STORE_ID="property-listings-ds"
DISPLAY_NAME="Property Listings"
CLUSTER_ID="hr-dev"
DATABASE_ID="postgres"
TABLE_ID="search.property_listings"

# Get Access Token
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Create Data Store via API
curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "https://discoveryengine.googleapis.com/v1alpha/projects/$PROJECT_ID/locations/global/collections/default_collection/dataStores?dataStoreId=$DATA_STORE_ID" \
  -d '{
    "displayName": "'"$DISPLAY_NAME"'",
    "industryVertical": "GENERIC",
    "solutionTypes": ["SOLUTION_TYPE_SEARCH"],
    "contentConfig": "CONTENT_REQUIRED",
    "alloyDbSource": {
      "projectId": "'"$PROJECT_ID"'",
      "locationId": "'"$REGION"'",
      "clusterId": "'"$CLUSTER_ID"'",
      "databaseId": "'"$DATABASE_ID"'",
      "tableId": "'"$TABLE_ID"'"
    }
  }'
```
*Note: This uses the `v1alpha` API. Ensure the `discoveryengine.googleapis.com` API is enabled.*


## 8. Deployment
Once infrastructure is ready:
0. Run ./debug_local.sh to test the application locally.
1.  Run `./setup_env.sh` to configure your environment variables.
2.  Run `./deploy.sh` to build and deploy the application.
