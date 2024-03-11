# This part creates environment
resource "confluent_environment" "development" {
  display_name = "SmartWarehouse"
  lifecycle {
    prevent_destroy = true
  }
}

# This part creates cluster inside environment
resource "confluent_kafka_cluster" "basic" {
  display_name = "Smart Warehouse"
  availability = "SINGLE_ZONE"
  cloud        = "GCP"
  region       = "us-central"
  basic {}

  environment {
    id = confluent_environment.development.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# This part creates service account
resource "confluent_service_account" "tf_cluster_admin" {
  display_name = "tf_cluster_admin"
  description  = "terraform cluster admin service account"
}

# This part assigned role to the user  account created
resource "confluent_role_binding" "tf_cluster_admin-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.tf_cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

# This part creates API Key for service account
resource "confluent_api_key" "tf_cluster_admin_apikey" {
  display_name = "tf_cluster_admin_apikey"
  description  = "Kafka API Key that is owned by 'tf_cluster_admin' service account"
  owner {
    id          = confluent_service_account.tf_cluster_admin.id
    api_version = confluent_service_account.tf_cluster_admin.api_version
    kind        = confluent_service_account.tf_cluster_admin.kind
    }
  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind
    environment {
      id = confluent_environment.development.id
    }
  }
}
