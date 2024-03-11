# Real-Time Data Streaming for Smart Warehouses

Data streaming technologies like Apache Kafka have become a fundamental part of the underlying infrastructure of gaming applications. This is because they enable real-time stream processing (facilitating improved user experiences), are able to handle large volumes of complex data, and can scale across distributed servers and data centers.

Confluent Cloud – the complete, cloud-native and ‘everywhere’ version of Apache Kafka – is used by many gaming companies as the backbone of their data infrastructures. In this demonstration, we’ll show why by guiding you through three technical aspects of Confluent which facilitate the delivery of gaming applications. These are:

* Producing Multiple Event Types in Single Topic
* Preventing duplicate messages with ksqlDB
* Monitoring and observing event streams

By exploring these aspects, you will gain a deeper understanding of how Confluent Cloud can be adapted to a wide range of gaming applications.

## Requirements

In order to successfully complete this demo you need to install few tools before getting started.

- If you don't have a Confluent Cloud account, sign up for a free trial [here](https://www.confluent.io/confluent-cloud/tryfree).
- Install Confluent Cloud CLI by following the instructions [here](https://docs.confluent.io/confluent-cli/current/install.html).
- Please follow the instructions to install Terraform if it is not already installed on your system [here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  

## Prerequisites

### 1. Confluent Cloud

1. Sign up for a Confluent Cloud account [here](https://www.confluent.io/get-started/).
2. After verifying your email address, access Confluent Cloud sign-in by navigating [here](https://confluent.cloud).
3. When provided with the _username_ and _password_ prompts, fill in your credentials.

   > **Note:** If you're logging in for the first time you will see a wizard that will walk you through the some tutorials. Minimize this as you will walk through these steps in this guide.

4. Create *Confluent Cloud API keys* by following the steps in UI. Click on the hamburger icon that is present on the right top section and click on Cloud API Keys.

<div align="center">
  <img src="images/cloud1.png" width =100% heigth=100%>
</div>

5. In the Access Control menu, select Global Access and click on the Next Button

 <div align="center">
  <img src="images/cloud2.png" width =100% heigth=100%>
  <br>
</div>

6. Now Click Add Key to generate API keys and store it as we will be using this key on terraform to deploy the infrastructure.

   > **Note:** This is different than Kafka Cluster API keys.

### 2. Setting up your Confluent Cloud Infrastructure

This demo uses Terraform to spin up the entire infrastructure and the resources that are needed for this demo. This terraform code creates the confluent cloud cluster, ksqldb, schema registry and also topics that are needed for the demo.

2. Navigate to the repo's terraform directory.

  ```bash
  cd terraform
  ```

3. Update the `terraform/variables.tf` file for the following variables with your Cloud API credentials from the previous step.

  ```
  variable "confluent_cloud_api_key" {
    default = "Replace with your API Key created during pre-requesite"
  }

  variable "confluent_cloud_api_secret" {
    default = "Replace with your API Secret created during pre-requesite"   
  }
  ```

4. Initialize Terraform within the directory.

  ```
  terraform init
  ```

5. Use the following command to create the terraform plan which validates all the components described in the terraform script

  ```
  terraform plan
  ```

6. Apply the plan to create the infrastructure. This should take few minutes to setup.

  ```
  terraform apply
  ```

   > **Note:** Read the `main.tf` and the other component specific (.tf) configuration files [to see what will be created](./terraform/main.tf).

7. Once the Infrastructure is setup, you can see that the Bootstrap Server,Schema Registry Endpoint, API Key and Secret Values are displayed on the terminal (API Secret will be marked as sensitive). Use the following command to reveal the API Secret.

  ```
  terraform output -raw client_api_secret
  ```

<div align="center">
  <img src="images/terminal1.png" width =100% heigth=100%>
</div>

5. The follwoing credentials - *Bootstrap URL, Cluster API Key, Cluster API Secret, Scehma Registry URL, Schema Registry API Key, Schema Registry API Secret* are stored to credentials.txt file in the files directory.

   > **Note:** The python files in the further steps in the demo will read the credentials directly from the credentials.txt file, so refrain moving this file from the files directory.

### 3. Setting up Python Environment:


### Architecture Diagram:

<div align="center">
  <img src="images/smart_warehouse_architecture.png" width =80% heigth=100% align=center>
</div>

## 2. Preventing duplicate message with ksqlDB:

Duplicate messages can significantly disrupt a gamer’s experience in a number of different ways. They can trigger glitches in player behavior, break game logic and cause applications to crash.

This can be avoided by leveraging stream processing – either with flink or ksqlDB – to process and remove duplicate events. In this example, we use Flink.

### Generate Sample data using datagen connector:


### 1. Create a Stream into the ksqldb Stream Functions by updating the timestamp

  ```
  CREATE STREAM TXN_RAW (
      ID STRING,
      USER_ID STRING,
      TXN_TYPE STRING,
      TXN_TIMESTAMP STRING)
  WITH (KAFKA_TOPIC='txn_raw',
        TIMESTAMP='txn_timestamp',
        TIMESTAMP_FORMAT='yyyy-MM-dd HH:mm:ss',
        VALUE_FORMAT='JSON',
        PARTITIONS=3);

  ```

### 2. Create another Stream by repartioning the messages to handle all keyless messages stored in round robin fashion in the topics.

  ```
  CREATE STREAM TXN_PARTITIONEDBY_TXNID
    WITH (KAFKA_TOPIC='txn_raw_key_txn_id',
          VALUE_FORMAT='AVRO',
          KEY_FORMAT='KAFKA') AS
      SELECT
          ID AS ID_KEY,
          AS_VALUE(ID) AS ID,
          USER_ID,
          TXN_TYPE
      FROM TXN_RAW
      PARTITION BY ID;

  ```

### 3. Create a Table to disable the buffering to get the results faster

  ```
  Add specific query property
  SET 'cache.max.bytes.buffering' = '0';

  CREATE TABLE TXN_WINDOW_10MIN_UNIQUE_TABLE
  WITH (KAFKA_TOPIC='txn_window_10min_unique',
      VALUE_FORMAT='AVRO',
      KEY_FORMAT='KAFKA')
  AS
    SELECT
        ID_KEY,
        EARLIEST_BY_OFFSET(ID) AS ID,
        EARLIEST_BY_OFFSET(USER_ID) AS USER_ID,
        EARLIEST_BY_OFFSET(TXN_TYPE) AS TXN_TYPE,
        COUNT(*) AS MESSAGE_NO
    FROM TXN_PARTITIONEDBY_TXNID
    WINDOW TUMBLING (SIZE 10 MINUTES, GRACE PERIOD 2 MINUTES)
    GROUP BY ID_KEY
    HAVING COUNT(*) = 1;
  ```

### 4. Create a new Stream to capture unique transactions every 10 minutes with a 2 minute grace period:

  ```
  CREATE STREAM TXN_WINDOW_10MIN_UNIQUE_STREAM (
    ID_KEY STRING KEY,
    ID STRING,
    USER_ID STRING,
    TXN_TYPE STRING,
    MESSAGE_NO BIGINT)
  WITH (KAFKA_TOPIC='txn_window_10min_unique',
        VALUE_FORMAT='AVRO',
        KEY_FORMAT='KAFKA');
  ```

### 5. Create a Stream of unique transactions:

  ```
  CREATE STREAM TXN_UNIQUE (
    ID_KEY STRING KEY,
    ID STRING,
    USER_ID STRING,
    TXN_TYPE STRING,
    MESSAGE_NO BIGINT)
  WITH (KAFKA_TOPIC='txn_unique',
        VALUE_FORMAT='AVRO',
        KEY_FORMAT='KAFKA',
        PARTITIONS=3);
  ```

### 6. Create a Transaction Lookup Table which will create a timestamp for the first event of the transaction.

  ```
  CREATE TABLE TXN_LOOKUP_TABLE
  WITH (KAFKA_TOPIC='txn_lookup_table',
        VALUE_FORMAT='AVRO',
        KEY_FORMAT='KAFKA')
    AS
      SELECT ID_KEY,
          EARLIEST_BY_OFFSET(ID) AS ID,
          TIMESTAMPTOSTRING(EARLIEST_BY_OFFSET(ROWTIME), 'yyyy-MM-dd HH:mm:ss.SSS') AS MSG_ROWTIME,
          EARLIEST_BY_OFFSET(ROWTIME) AS MSG_EPOCH
      FROM TXN_UNIQUE
      GROUP BY ID_KEY;
  ```

### 7. Check duplicate transactions arrived after the 10 minutes window with the global table and add if not present in the lookup table

  ```
  INSERT INTO TXN_UNIQUE
    SELECT
        T10.ID_KEY AS ID_KEY,
        T10.ID AS ID,
        T10.USER_ID AS USER_ID,
        T10.TXN_TYPE AS TXN_TYPE,
        T10.MESSAGE_NO AS MESSAGE_NO
    FROM TXN_WINDOW_10MIN_UNIQUE_STREAM T10
        LEFT JOIN TXN_LOOKUP_TABLE TLT ON T10.ID_KEY = TLT.ID_KEY
    WHERE T10.ID_KEY IS NOT NULL
        AND TLT.ID_KEY IS NULL
    EMIT CHANGES;
  ```

### 8. Create a Stream for lookup table cleaning by inserting a tombstone message as ksqldb memory

  ```
  CREATE STREAM TXN_LOOKUP_TABLE_CLEANING_STREAM (
    ID_KEY STRING KEY,
    DUMMY STRING)
  WITH (KAFKA_TOPIC='txn_lookup_table',
       VALUE_FORMAT='AVRO',
       KEY_FORMAT='KAFKA');
  ```

Even though it looks like a quick fix to generate TTL in ksqlDB, you need to be careful while sending Tombstones because some of the Apache Kafka Clients have different default hashing strategies. Using a disparate hashing method will generate a different hash key which will cause the keys ending up in different partitions. It will defeat the purpose of this cleaning step and make sure that clients use the same hashing strategy as the ksqlDB.

### Stream Lineage:

Once you have completed all the steps, you will have the complete stream lineage as shown below:

  <div align="center">
    <img src="images/stream-lineage.png" width =100% heigth=100%>
  </div>

You can access the Stream Lineage Feature inside Confluent Cloud by accessing the *Stream Lineage* menu in the left sidebar of the Confluent Cloud Dashboard.

## 3. Observability of the gaming platform

The ability to observe and monitor the status of your streaming data pipelines is highly valued regardless of which applications they’re powering. In the context of gaming applications, observability and monitoring help to ensure that platforms remain online and there’s no disruption to play.

In this demo, we’re going to use Fluent Bit to process logs and identify SSH (Secure Shell) attacks. As a lightweight, highly scalable logging and metrics processor, Fluent Bit is well suited to delivering observability pipelines for gaming applications. Please follow the following steps to continue with the demo.


### Check logs on Confluent Cloud:

The fluent bit client sends a load of sample data located in the fluent-bit/syslog.log file to the kafka cluster. You can check this by heading over to Confluent Cloud and check the messages inside the **logs** topic.

### Use kqlDB to check for ssh attacks in the logs:

Let us see a quick example on how to use ksqldb to process the logs and look for ssh attacks. Follow the given steps to create a ssh_attacks stream based on the logs received.

1. Create a Stream from the logs topic:

  ```bash
  CREATE STREAM syslog_stream (
    timestamp DOUBLE,
    log STRING)
  WITH (
    KAFKA_TOPIC='logs',
    VALUE_FORMAT='JSON');

  ```

2. Create actionable stream of SSH attacks, filtering syslog messages where user is invalid

  ```bash
  CREATE STREAM ssh_attacks_stream AS
    SELECT
      EXTRACTJSONFIELD(log, '$.ts') AS log_timestamp,
      EXTRACTJSONFIELD(log, '$.host') AS host,
      EXTRACTJSONFIELD(log, '$.message') AS message,
      EXTRACTJSONFIELD(log, '$.remote_address') AS remote_address,
      EXTRACTJSONFIELD(log, '$.facility') AS facility
    FROM logs
    WHERE EXTRACTJSONFIELD(log, '$.message') LIKE '%Invalid user%';
  ```

3. Create an enriched ssh_attacks_stream replacing the invalid users to attack users

  ```bash
  CREATE STREAM enriched_log_stream AS
  SELECT
    LOG_TIMESTAMP,
    HOST,
    CASE
      WHEN MESSAGE LIKE '%Invalid user%' THEN 'Attack user'
      ELSE FACILITY
    END AS FACILITY,
    REMOTE_ADDRESS
  FROM ssh_attacks_stream;
  ```

4. Create a user aggregate table

  ```bash
  CREATE TABLE user_aggregate_table AS
  SELECT
    HOST AS USER,
    COUNT(*) AS REPEAT_COUNT
  FROM enriched_log_stream
  GROUP BY HOST;
  ```

5. Create a persistent query to continuously update the user aggregate

  ```bash
  CREATE TABLE user_aggregate_result AS
  SELECT * FROM user_aggregate_table;
  ```

### Output data from Enriched Logs:

  <div align="center">
    <img src="images/enriched_log_stream.png" width =50% heigth=100%>
  </div>

We have obtained an enriched log stream using ksqldb and also we have created a table with the number of attack attempts based on the host.

This data can further be consumed into other alerting or notifications services to trigger alerts on the system.

## Other Features in Confluent Cloud

- High Availability
- Cloud Audit Logs
- Custom Connectors
- Encryption
- Stream Lineage
- Role Based Access Control (RBAC)

## Teardown

It's recommended that you delete any resources that were created during the demo so you don't incur additional charges. follow the steps below to stop generating additional data and stop all running services and drop the entire infrastructure spun up by terraform.


### Infrastructure:

1. Run the following command to delete all resources created by Terraform

  ```bash
  terraform apply -destroy
  ```
2. If you are prompted to delete the Persistent Queries if any, head over to the Confluent Cloud dashboard and then select ksqldb on the left menu and delete all queries inside the **Persistent Queries** section

# References

1. Introduction to ksqlDB - [tutorial](https://developer.confluent.io/courses/ksqldb/intro/)
2. Schema Registry overview - [doc](https://docs.confluent.io/platform/current/schema-registry/index.html)
3. Putting Several Event Types in the Same Topic – Revisited - [blog](https://www.confluent.io/en-gb/blog/multiple-event-types-in-the-same-kafka-topic/)
