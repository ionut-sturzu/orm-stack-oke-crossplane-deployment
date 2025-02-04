resource "oci_artifacts_container_repository" "test_container_repository" {
    #Required
    compartment_id = var.compartment_id
    display_name   = var.registry_display_name
    # is_immutable   = true
    is_public      = false
}

output "ocir_name" {
    value = oci_artifacts_container_repository.test_container_repository.display_name
}