data "confluent_schema_registry_region" "essentials" {
  cloud        = local.cloud
  region       = local.region
  package      = "ESSENTIALS"
}

resource "confluent_schema_registry_cluster" "essentials" {
  package = data.confluent_schema_registry_region.essentials.package

  environment {
    id = confluent_environment.SmartWarehouse.id
  }

  region {
    id = data.confluent_schema_registry_region.essentials.id
  }
}

resource "confluent_service_account" "env-manager" {
  display_name = "env-manager"
  description  = "Service account to manage 'Staging' environment"
}

resource "confluent_role_binding" "env-manager-environment-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.SmartWarehouse.resource_name
}

resource "confluent_api_key" "env-manager-schema-registry-api-key" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }

  managed_resource {
    id          = confluent_schema_registry_cluster.essentials.id
    api_version = confluent_schema_registry_cluster.essentials.api_version
    kind        = confluent_schema_registry_cluster.essentials.kind

    environment {
      id = confluent_environment.SmartWarehouse.id
    }
  }

  depends_on = [
    confluent_role_binding.env-manager-environment-admin
  ]
}
