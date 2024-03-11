from uuid import uuid4
import os, random
from confluent_kafka import Producer
from confluent_kafka.serialization import StringSerializer, SerializationContext, MessageField
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer

# reading credentials from files/credentials.txt
creds_file = open(os.path.dirname(__file__) + '/../files/credentials.txt')
for line in creds_file.readlines():
    if (line.split(' = ')[0]) == 'cluster_bootstrap':
        cluster_bootstrap = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'cluster_api_key':
        cluster_api_key = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'cluster_api_secret':
        cluster_api_secret = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'schemaregistry_url':
        schemaregistry_url = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'schemaregistry_api_key':
        schemaregistry_api_key = line.split(' = ')[1].strip()
    elif (line.split(' = ')[0]) == 'schemaregistry_api_secret':
        schemaregistry_api_secret = line.split(' = ')[1].strip()

schema_str = []

class PlayerHealth(object):
    def __init__(self, player_id, health, timestamp):
        self.player_id = player_id
        self.health = health
        self.timestamp = timestamp

def player_health_to_dict(player_health, ctx):
    return dict(player_id=player_health.player_id,
                health=player_health.health,
                timestamp=player_health.timestamp)

class PlayerPosition(object):
    def __init__(self, player_id, x, y):
        self.player_id = player_id
        self.x = x
        self.y = y

def player_position_to_dict(player_health, ctx):
    return dict(player_id=player_health.player_id,
                x=player_health.x,
                y=player_health.y)

def delivery_report(err, msg):
    if err is not None:
        print("Delivery failed for User record {}: {}".format(msg.key(), err))
        return
    else:
        print('User record {} successfully produced to {} [{}] at offset {}'.format(
        msg.key(), msg.topic(), msg.partition(), msg.offset()))

def main():
    topic = 'game-events'
    schema0 = 'player_health.avsc'
    schema1 = 'player_position.avsc'
    path = os.path.realpath(os.path.dirname(__file__))[:-6] + 'terraform/schemas/'
    with open(f"{path}{schema0}") as f0:
        schema_str0 = f0.read()
    with open(f"{path}{schema1}") as f1:
        schema_str1 = f1.read()

    schema_registry_conf = {
        'url': schemaregistry_url,
        'basic.auth.user.info': schemaregistry_api_key + ':' + schemaregistry_api_secret
        }
    schema_registry_client = SchemaRegistryClient(schema_registry_conf)
    
    serializer_configs = {
        'auto.register.schemas': False,
        'use.latest.version': True
    }
    string_serializer = StringSerializer('utf_8')
    avro_serializer0 = AvroSerializer(schema_registry_client,schema_str0,player_health_to_dict, serializer_configs)
    avro_serializer1 = AvroSerializer(schema_registry_client,schema_str1,player_position_to_dict, serializer_configs)

    producer_conf = {
        'bootstrap.servers': cluster_bootstrap,
        'client.id': 'producer_py',
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': cluster_api_key,
        'sasl.password': cluster_api_secret,
        'linger.ms': 0,
        'batch.size': 65536,
        'request.timeout.ms': 900000,
        'queue.buffering.max.ms': 100,
        'retries': 10000000,
        'socket.timeout.ms': 500,
        'default.topic.config': {
            'acks': 'all',
            'message.timeout.ms': 5000,
            }
        }
    producer = Producer(producer_conf)

    print("Producing record to topic {}. ^C to exit.".format(topic))
    while True:
        choice = random.randint(0, 1)
        producer.poll(0.0)
        if choice == 0:
            print('Generating [PlayerHealth] record.')
            player_id = gen_player_id()
            health = gen_health()
            timestamp = 1660857600000
            try: 
                playerhealth = PlayerHealth(player_id=player_id,
                            health=health,
                            timestamp=timestamp)
                producer.produce(topic=topic,
                                    key=string_serializer(str(uuid4())),
                                    value=avro_serializer0(playerhealth, SerializationContext(topic, MessageField.VALUE)),
                                    on_delivery=delivery_report)
            except ValueError:
                print("Invalid input, discarding record...")
        elif choice == 1:
            print('Generating [PlayerPosition] record.')
            player_id = gen_player_id()
            x = gen_x()
            y = gen_y()
            try: 
                playerposition = PlayerPosition(player_id=player_id,
                            x=x,
                            y=y)
                producer.produce(topic=topic,
                                    key=string_serializer(str(uuid4())),
                                    value=avro_serializer1(playerposition, SerializationContext(topic, MessageField.VALUE)),
                                    on_delivery=delivery_report)
            except ValueError:
                print("Invalid input, discarding record...")
        
        #print("\nFlushing records...")
        producer.flush()

def gen_player_id():
    return 'player' + str(random.randint(1, 15))

def gen_health():
    return int(random.randint(10, 99))

def gen_x():
    return float(random.randint(101,999)/10)

def gen_y():
    return float(random.randint(101,999)/10)

if __name__ == '__main__':
    main()