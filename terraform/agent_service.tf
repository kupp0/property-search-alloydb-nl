# Cloud Run Service for ADK Agent
resource "google_cloud_run_v2_service" "agent_service" {
  name     = "adk-agent-service"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-central1-docker.pkg.dev/${var.project_id}/search-demo-repo/agent-service:latest"
      
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GOOGLE_CLOUD_REGION"
        value = var.region
      }
      env {
        name  = "TOOLBOX_URL"
        # Point to the deployed MCP Server URL
        # We need to know the MCP Server URL. 
        # Assuming mcp-server service is named "toolbox" in mcp_server.tf
        value = google_cloud_run_v2_service.toolbox.uri
      }
      env {
        name = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "true"
      }
      env {
        name = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }
      
      ports {
        container_port = 8080
      }
    }
    
    service_account = google_service_account.run_sa.email
  }

  depends_on = [
    google_project_service.services,
    google_cloud_run_v2_service.toolbox
  ]
}

# Allow unauthenticated access to the agent service (for demo purposes)
# In production, you might want to restrict this.
resource "google_cloud_run_service_iam_member" "agent_public_access" {
  location = google_cloud_run_v2_service.agent_service.location
  service  = google_cloud_run_v2_service.agent_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "agent_service_url" {
  value = google_cloud_run_v2_service.agent_service.uri
}
