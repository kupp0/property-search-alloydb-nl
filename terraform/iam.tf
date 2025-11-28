# IAM Configuration

# Get the Project Number
data "google_project" "project" {
  project_id = google_project.project.project_id
}

# Default Compute Engine Service Account
locals {
  service_account_email = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Grant required roles to the Service Account
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/alloydb.client",
    "roles/logging.logWriter",
    "roles/artifactregistry.repoAdmin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/aiplatform.user",
    "roles/aiplatform.user",
    "roles/discoveryengine.editor",
    "roles/storage.objectAdmin"
  ])

  project = google_project.project.project_id
  role    = each.key
  member  = "serviceAccount:${local.service_account_email}"

  depends_on = [google_project_service.services]
}

# AlloyDB Service Agent (Required for AI/ML integration)
locals {
  alloydb_sa_email = "service-${data.google_project.project.number}@gcp-sa-alloydb.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "alloydb_sa_vertex_ai" {
  project = google_project.project.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${local.alloydb_sa_email}"

  depends_on = [google_project_service.services]
}
