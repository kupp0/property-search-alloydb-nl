output "project_id" {
  value = google_project.project.project_id
}

output "alloydb_cluster_id" {
  value = google_alloydb_cluster.default.cluster_id
}

output "alloydb_primary_instance_id" {
  value = google_alloydb_instance.primary.instance_id
}

output "alloydb_public_ip" {
  value = google_alloydb_instance.primary.public_ip_address
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.repo.name
}

output "vertex_ai_data_store_id" {
  value = var.data_store_id
}

output "gcs_bucket_name" {
  value = google_storage_bucket.images_bucket.name
}
