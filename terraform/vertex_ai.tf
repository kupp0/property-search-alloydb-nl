# Vertex AI Search Data Store (Preview Feature Workaround)

resource "null_resource" "vertex_ai_data_store" {
  triggers = {
    project_id = google_project.project.project_id
    region     = var.region
    cluster_id = google_alloydb_cluster.default.cluster_id
  }

  provisioner "local-exec" {
    command = <<EOT
      ACCESS_TOKEN=$(gcloud auth print-access-token)
      curl -X POST \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        "https://discoveryengine.googleapis.com/v1alpha/projects/${google_project.project.project_id}/locations/global/collections/default_collection/dataStores?dataStoreId=${var.data_store_id}" \
        -d '{
          "displayName": "${var.data_store_display_name}",
          "industryVertical": "GENERIC",
          "solutionTypes": ["SOLUTION_TYPE_SEARCH"],
          "contentConfig": "CONTENT_REQUIRED",
          "alloyDbSource": {
            "projectId": "${google_project.project.project_id}",
            "locationId": "${var.region}",
            "clusterId": "${google_alloydb_cluster.default.cluster_id}",
            "databaseId": "postgres",
            "tableId": "search.property_listings"
          }
        }'
    EOT
  }

  depends_on = [
    google_alloydb_instance.primary,
    google_project_iam_member.sa_roles,
    google_project_service.services
  ]
}
