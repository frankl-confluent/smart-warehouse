resource "confluent_kafka_topic" "game-events" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "game-events"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.tf_cluster_admin_apikey.id
    secret = confluent_api_key.tf_cluster_admin_apikey.secret
  }
}

resource "confluent_kafka_topic" "transactions" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "transactions"
  partitions_count = 3
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.tf_cluster_admin_apikey.id
    secret = confluent_api_key.tf_cluster_admin_apikey.secret
  }
}

resource "confluent_kafka_topic" "logs" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "logs"
  partitions_count = 1
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.tf_cluster_admin_apikey.id
    secret = confluent_api_key.tf_cluster_admin_apikey.secret
  }
}