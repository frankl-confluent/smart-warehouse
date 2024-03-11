# resource "confluent_connector" "datagen-source" {
#   environment {
#     id = "env-97ryr0" #change to confluent_environment.development.id
#   }
#   kafka_cluster {
#     id = confluent_kafka_cluster.basic.id
#   }
#   config_sensitive = {}
#   config_nonsensitive = {
#     "connector.class"          = "DatagenSource"
#     "name"                     = "DatagenSource0"
#     "kafka.auth.mode"          = "SERVICE_ACCOUNT"
#     "kafka.service.account.id" = confluent_service_account.tf_cluster_admin.id
#     "kafka.topic"              = confluent_kafka_topic.sample_topic.topic_name
#     "output.data.format"       = "JSON"
#     "quickstart"               = "ORDERS"
#     "tasks.max"                = "1"
#   }
#   depends_on = [
#     confluent_api_key.tf_cluster_admin_apikey,
#   ]
# }