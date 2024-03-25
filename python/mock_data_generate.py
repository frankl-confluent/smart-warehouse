from uuid import uuid4
import os, random
from decimal import *
from confluent_kafka import Producer
from confluent_kafka.serialization import StringSerializer, SerializationContext, MessageField
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer

# reading credentials from producer.properties 
creds_file = open(os.path.dirname(__file__) + '/producer.properties')
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

class BatteryStatus(object):
    def __init__(self, battery_id, battery_type, battery_charge, timestamp):
        self.picker_robot_id = battery_id
        self.battery_type_id = battery_type
        self.battery_charge = battery_charge
        self.event_time = timestamp

def battery_status_to_dict(battery_status, ctx):
    # print(str(battery_status.picker_robot_id) +"..."+str(battery_status.battery_type_id)+"..."+str(battery_status.battery_charge)+"..."+str(battery_status.event_time))
    return dict(picker_robot_id=battery_status.picker_robot_id,
                battery_type_id=battery_status.battery_type_id,
                battery_charge=battery_status.battery_charge,
                event_time=battery_status.event_time)

def delivery_report(err, msg):
    if err is not None:
        print("Delivery failed for User record {}: {}".format(msg.key(), err))
        return
    else:
        print('User record {} successfully produced to {} [{}] at offset {}'.format(
        msg.key(), msg.topic(), msg.partition(), msg.offset()))

def main():
    topic = 'picker_robot_battery_status'
    init_timestamp = 1710951030000
    schema0 = 'battery.avsc'
    path = os.path.realpath(os.path.dirname(__file__))[:-6] + 'python/'
    with open(f"{path}{schema0}") as f0:
        schema_str0 = f0.read()

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
    avro_serializer0 = AvroSerializer(schema_registry_client,schema_str0,battery_status_to_dict, serializer_configs)
    
    battery_map = {
        1001 : { "type": 111, "current": 1.0, "timestamp": init_timestamp, "step": 0.001 },
        1002 : { "type": 222, "current": 1.0, "timestamp": init_timestamp, "step": 0.00002 },
        1003 : { "type": 111, "current": 1.0, "timestamp": init_timestamp, "step": 0.00004 },
        1004 : { "type": 333, "current": 0.5, "timestamp": init_timestamp, "step": 0.0008 },
        1005 : { "type": 444, "current": 1.0, "timestamp": init_timestamp, "step": 0.00005 },
        1006 : { "type": 111, "current": 1.0, "timestamp": init_timestamp, "step": 0.00007 },
        1007 : { "type": 222, "current": 1.0, "timestamp": init_timestamp, "step": 0.00002 },
        1008 : { "type": 111, "current": 0.15, "timestamp": init_timestamp, "step": 0.00005 },
        1009 : { "type": 333, "current": 1.0, "timestamp": init_timestamp, "step": 0.00003 },
        1010 : { "type": 111, "current": 1.0, "timestamp": init_timestamp, "step": 0.00006 }
    }

    producer_conf = {
        'bootstrap.servers': cluster_bootstrap,
        'client.id': 'batter_producer_py',
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
    count = 10000
    TWOPLACES = Decimal(10) ** -2 
    while count > 0:
        producer.poll(0.0)
        print('Generating Battery Status record.')
        battery_id = gen_battery_id()
        battery_type = battery_map[battery_id]['type']
        if battery_map[battery_id]['current'] - battery_map[battery_id]['step'] <= 0:
            battery_charge = 0
        else:
            battery_charge = battery_map[battery_id]['current'] - battery_map[battery_id]['step']
        timestamp = battery_map[battery_id]['timestamp'] + 60000
        battery_map[battery_id]['current'] = battery_charge
        battery_map[battery_id]['timestamp'] = timestamp
        battery_charge_t = Decimal(battery_charge).quantize(TWOPLACES)
        try: 
            batteryStatus = BatteryStatus(battery_id=battery_id,
                                          battery_type=battery_type,
                                          battery_charge=battery_charge_t,
                                          timestamp=timestamp)
            producer.produce(topic=topic,
                            key=string_serializer(str(uuid4())),
                            value=avro_serializer0(batteryStatus, SerializationContext(topic, MessageField.VALUE)),
                            on_delivery=delivery_report)
        except ValueError as e:
            print("Invalid input, discarding record...")
        
        print("\nFlushing records...")
        producer.flush()
        count = count - 1

def gen_battery_id():
    return 1000 + random.randint(1, 10)

if __name__ == '__main__':
    main()
