# https://docs.confluent.io/cloud/current/flink/get-started/quick-start-cloud-console.html#step-1-create-a-af-compute-pool
resource "confluent_flink_compute_pool" "swh" {
  display_name = "swh-compute-pool"
  cloud        = local.cloud
  region       = local.region
  max_cfu      = 5
  environment {
    id = confluent_environment.SmartWarehouse.id
  }
  depends_on = [
    confluent_role_binding.statements-runner-environment-admin,
    confluent_role_binding.app-manager-assigner,
    confluent_role_binding.app-manager-flink-developer,
    confluent_api_key.app-manager-flink-api-key,
  ]
}

// Service account to perform a task within Confluent Cloud, such as executing a Flink statement
resource "confluent_service_account" "flink-statements-runner" {
  display_name = "flink-statements-runner"
  description  = "Service account for running Flink Statements in 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "statements-runner-environment-admin" {
  principal   = "User:${confluent_service_account.flink-statements-runner.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.SmartWarehouse.resource_name
}

resource "confluent_service_account" "flink-app-manager" {
  display_name = "flink-app-manager"
  description  = "Service account that has got full access to Flink resources in an environment"
}

resource "confluent_role_binding" "app-manager-flink-developer" {
  principal   = "User:${confluent_service_account.flink-app-manager.id}"
  role_name   = "FlinkAdmin"
  crn_pattern = confluent_environment.SmartWarehouse.resource_name
}

// https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html#submit-long-running-statements
resource "confluent_role_binding" "app-manager-assigner" {
  principal   = "User:${confluent_service_account.flink-app-manager.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.flink-statements-runner.id}"
}

data "confluent_flink_region" "my_flink_region" {
  cloud        = local.cloud
  region       = local.region
}

data "confluent_organization" "main" {}

resource "confluent_api_key" "app-manager-flink-api-key" {
  display_name = "app-manager-flink-api-key"
  description  = "Flink API Key that is owned by 'flink-app-manager' service account"
  owner {
    id          = confluent_service_account.flink-app-manager.id
    api_version = confluent_service_account.flink-app-manager.api_version
    kind        = confluent_service_account.flink-app-manager.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.my_flink_region.id
    api_version = data.confluent_flink_region.my_flink_region.api_version
    kind        = data.confluent_flink_region.my_flink_region.kind
    environment {
      id = confluent_environment.SmartWarehouse.id
    }
  }
}

resource "confluent_flink_statement" "create_threshold_table" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.SmartWarehouse.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.swh.id
  }
  principal {
    id = confluent_service_account.flink-statements-runner.id
  }
  statement = <<EOT
     CREATE TABLE battery_thresholds (
          `battery_type_id` INT NOT NULL
        , `battery_type` STRING  
        , `min_charge_percentage_allowed_for_active_pickers` DECIMAL(10,2)
        , `max_rate_of_decreasing_charge_per_hour` DECIMAL(10,2)
        , PRIMARY KEY(`battery_type_id`) NOT ENFORCED
    );
    EOT

  properties = {
    "sql.current-catalog"  = confluent_environment.SmartWarehouse.display_name
    "sql.current-database" = confluent_kafka_cluster.swh.display_name
  }
  rest_endpoint = data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_flink_statement" "insert_threshold_table" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.SmartWarehouse.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.swh.id
  }
  principal {
    id = confluent_service_account.flink-statements-runner.id
  }
  statement = <<EOT
		EXECUTE STATEMENT SET
		BEGIN
                    INSERT INTO battery_thresholds VALUES (111, 'robot_picker_battery',.10,.05);
		    INSERT INTO battery_thresholds VALUES (222, 'robot_picker_battery',.10,.06);
		    INSERT INTO battery_thresholds VALUES (333, 'robot_picker_battery',.10,.04);
  		    INSERT INTO battery_thresholds VALUES (444, 'robot_picker_battery',.10,.05); 
                END;
               EOT

  properties = {
    "sql.current-catalog"  = confluent_environment.SmartWarehouse.display_name
    "sql.current-database" = confluent_kafka_cluster.swh.display_name
  }
  rest_endpoint = data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_statement.create_threshold_table,
  ]
  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_flink_statement" "create_status_table" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.SmartWarehouse.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.swh.id
  }
  principal {
    id = confluent_service_account.flink-statements-runner.id
  }
  statement = <<EOT
     CREATE TABLE picker_robot_battery_status(
         `picker_robot_id` INT NOT NULL
       , `battery_type_id` INT NOT NULL  
       , `battery_charge` DECIMAL(10,2)
       , `event_time` TIMESTAMP_LTZ(3)
       , WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND  
     );
     EOT

  properties = {
    "sql.current-catalog"  = confluent_environment.SmartWarehouse.display_name
    "sql.current-database" = confluent_kafka_cluster.swh.display_name
  }
  rest_endpoint = data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
