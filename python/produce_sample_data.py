from confluent_kafka import Producer
import json
import random
import time
import os

creds_file = open(os.path.dirname(__file__) + '/../files/credentials.txt')
for line in creds_file.readlines():
    if (line.split(' = ')[0]) == 'cluster_bootstrap':
        cluster_bootstrap = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'cluster_api_key':
        cluster_api_key = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'cluster_api_secret':
        cluster_api_secret = line.split(' = ')[1].strip()

# Confluent Cloud SASL configurations
conf = {
    'bootstrap.servers': cluster_bootstrap,
    'sasl.mechanisms': 'PLAIN',
    'security.protocol': 'SASL_SSL',
    'sasl.username': cluster_api_key,
    'sasl.password': cluster_api_secret,
}

# Create a Kafka producer instance
producer = Producer(conf)

# Topic to produce to
topic = "transactions"

# Continuous data generation and production
while True:
    key = {
        'id_key': f'txn{random.randint(1, 100)}'
    }

    value = {
        'id': key['id_key'],
        'user_id': f'user{random.randint(1, 100)}',
        'txn_type': random.choice(['purchase', 'refund']),
        'txn_timestamp': '2023-04-10 08:00:00',
        'total_sales': random.uniform(1, 1000),
        'currency': random.choice(['USD', 'EUR', 'JPY']),
        'items': [f'item{random.randint(1, 10)}' for _ in range(random.randint(1, 5))]
    }

    # Produce the message
    producer.produce(topic, key=json.dumps(key), value=json.dumps(value))
    print("Record produced: {}".format(json.dumps(key)))
    # Wait for a short interval between messages
    time.sleep(1)
