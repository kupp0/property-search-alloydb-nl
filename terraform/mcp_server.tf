resource "google_service_account" "toolbox_identity" {
  account_id   = "toolbox-identity"
  display_name = "Toolbox Identity Service Account"
  project      = google_project.project.project_id
}

resource "google_secret_manager_secret" "toolbox_config" {
  secret_id = "tools"
  project   = google_project.project.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "toolbox_config_version" {
  secret = google_secret_manager_secret.toolbox_config.id
  secret_data = file("${path.module}/../backend/mcp_server/tools.yaml")
}

resource "google_project_iam_member" "toolbox_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.toolbox_identity.email}"
}

resource "google_project_iam_member" "toolbox_alloydb_client" {
  project = var.project_id
  role    = "roles/alloydb.client"
  member  = "serviceAccount:${google_service_account.toolbox_identity.email}"
}

resource "google_project_iam_member" "toolbox_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.toolbox_identity.email}"
}

resource "google_cloud_run_v2_service" "toolbox" {
  name     = "toolbox"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = google_project.project.project_id

  template {
    service_account = google_service_account.toolbox_identity.email

    containers {
      image = "us-central1-docker.pkg.dev/database-toolbox/toolbox/toolbox:latest"
      
      args = [
        "--tools-file=/secrets/tools.yaml",
        "--address=0.0.0.0",
        "--port=8080"
      ]

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }

      ports {
        container_port = 8080
      }

      volume_mounts {
        name       = "tools-config"
        mount_path = "/secrets"
      }
    }

    volumes {
      name = "tools-config"
      secret {
        secret = google_secret_manager_secret.toolbox_config.secret_id
        items {
          version = "latest"
          path    = "tools.yaml"
        }
      }
    }
    
    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc_network.name
        subnetwork = google_compute_network.vpc_network.name
      }
      egress = "ALL_TRAFFIC"
    }
  }
  
  depends_on = [google_project_service.services]
}
