import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
import argparse # Importado para ler argumentos da consola

# CONFIGURAÇÕES DO MONGODB
# Se estiver a ser usado o Docker, estas credenciais devem bater certo

# CONFIGURAÇÃO DE ARGUMENTOS
parser = argparse.ArgumentParser(description="Script: MQTT to MongoDB")
parser.add_argument('--broker', type=str, default="broker.hivemq.com", help="Endereço do Broker MQTT")
parser.add_argument('--mongo', type=str, default="mongodb://mongodb1:27018,mongodb2:27019,mongodb3:27020/?replicaSet=rs0", help="URI do MongoDB")
args = parser.parse_args()

# Ligar ao MongoDB usando o argumento
mongo_client = MongoClient(args.mongo)
db = mongo_client["sensores_db"]


# Definir as coleções
col_som = db["Som"]
col_temp = db["Temperatura"]
col_mov = db["Movimento"]



# Tópicos do grupo (n=7)
TOPIC_SOM = "pisid_mazesound_7"
TOPIC_TEMP = "pisid_mazetemp_7"
TOPIC_MOV = "pisid_mazemov_7"

# Dicionário para guardar apenas o texto da última mensagem de cada tópico
ultimas_mensagens = {}

# Callback quando o script se liga ao broker
def on_connect(client, userdata, flags, reason_code, properties):
    print(f"Ligado ao broker HiveMQ com sucesso! (Código: {reason_code})") # O reason_code 0 indica sucesso

    # QoS 2 para n haver duplicados
    client.subscribe([
        (TOPIC_SOM, 2),
        (TOPIC_TEMP, 2),
        (TOPIC_MOV, 2)
    ])
    print("A escutar mensagens (QoS 1) de todos os sensores...")


# Callback quando uma mensagem é recebida
def on_message(client, userdata, msg):
    topico = msg.topic
    payload = msg.payload.decode('utf-8')

    
    # Se já recebemos algo neste tópico antes, comparamos o texto atual com o último texto guardado
    if topico in ultimas_mensagens:
        # Se o texto for igual à última mensagem, é um eco da rede
        if payload == ultimas_mensagens[topico]:
            return # ignora o duplicado
            
    # Atualiza a memória com este novo texto para comparar com a próxima mensagem
    ultimas_mensagens[topico] = payload

    try:
        # Converter string JSON num dicionário Python
        documento = json.loads(payload)
    except json.JSONDecodeError:
        print(f"[{topico}] Ignorado - Formato JSON inválido: {payload}")
        return

    
    documento["Migrado"] = False
    documento["Anomalia"] = False

    if topico == TOPIC_SOM:
        documento["isOutlier"] = False
        col_som.insert_one(documento)
        
        # Preparamos um print sem o _id (criado pelo Mongo) só para a consola ficar limpa
        doc_print = {k: v for k, v in documento.items() if k != '_id'}
        print(f"[Som] Guardado no Mongo: {doc_print}")

    elif topico == TOPIC_TEMP:
        documento["isOutlier"] = False
        col_temp.insert_one(documento)
        
        doc_print = {k: v for k, v in documento.items() if k != '_id'}
        print(f"[Temperatura] Guardado no Mongo: {doc_print}")

    elif topico == TOPIC_MOV:
        col_mov.insert_one(documento)
        
        doc_print = {k: v for k, v in documento.items() if k != '_id'}
        print(f"[Movimento] Guardado no Mongo: {doc_print}")

# INICIAR O CLIENTE MQTT
# Usamos a API v2 que é a standard mais recente do Paho MQTT
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

print("A tentar ligar ao broker (Script 0 - Mqtt to MongoDB)...")
broker_address = args.broker.split(':')[0]
broker_port = int(args.broker.split(':')[1]) if ':' in args.broker else 1883 #opcional passar a porta broker:port ou so broker

client.connect(broker_address, broker_port, 60) # Usa o broker passado por argumento - 60 segundos de keepalive, para garantir que a ligação se mantém ativa mesmo que haja algum atraso na rede

# Manter o script a correr infinitamente
try:
    client.loop_forever()
except KeyboardInterrupt:
    print("\nScript terminado pelo utilizador.")
    client.disconnect()
    mongo_client.close()
