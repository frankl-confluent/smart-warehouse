output bootstrap_servers {
  value = confluent_kafka_cluster.basic.bootstrap_endpoint
}

output client_api_key {
  value = confluent_api_key.tf_cluster_admin_apikey.id
}

output client_api_secret {
  value = confluent_api_key.tf_cluster_admin_apikey.secret
  sensitive = true
}

output schema_registry_url {
  value = confluent_schema_registry_cluster.essentials.rest_endpoint
}

output env_api_key {
  value = confluent_api_key.env-manager-schema-registry-api-key.id
}

output env_api_secret {
  value = confluent_api_key.env-manager-schema-registry-api-key.secret
  sensitive = true
}

resource "local_file" "create_creds_for_python" {
    filename = "../files/credentials.txt"
    content = templatefile("../files/credentials.tmpl", {
        bootstrap_server = substr(confluent_kafka_cluster.basic.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.tf_cluster_admin_apikey.id
        kafka_cluster_secret = confluent_api_key.tf_cluster_admin_apikey.secret
        sr_endpoint = confluent_schema_registry_cluster.essentials.rest_endpoint
        sr_env_key = confluent_api_key.env-manager-schema-registry-api-key.id
        sr_env_secret = confluent_api_key.env-manager-schema-registry-api-key.secret
    })
}

resource "local_file" "create_fluent-bit_configuration" {
    filename = "../fluent-bit/fluent-bit.conf"
    content = templatefile("../files/fluent-bit.tmpl", {
        bootstrap_server = substr(confluent_kafka_cluster.basic.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.tf_cluster_admin_apikey.id
        kafka_cluster_secret = confluent_api_key.tf_cluster_admin_apikey.secret
    })
}