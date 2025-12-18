resource "google_secret_manager_secret" "toolbox_config" {
  secret_id = "tools"
  project   = google_project.project.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "toolbox_config_version" {
  secret      = google_secret_manager_secret.toolbox_config.id
  secret_data = file("${path.module}/../backend/mcp_server/tools.yaml")
}
