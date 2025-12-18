resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "search-app-repo"
  description   = "Docker repository for Search App"
  format        = "DOCKER"
  project       = google_project.project.project_id

  depends_on = [google_project_service.services]
}
