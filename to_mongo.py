import collections
import collections.abc

# CORREÇÃO OBRIGATÓRIA PARA PYTHON 3.13
collections.MutableMapping = collections.abc.MutableMapping
collections.Mapping = collections.abc.Mapping
collections.Iterable = collections.abc.Iterable
collections.MutableSet = collections.abc.MutableSet
collections.Callable = collections.abc.Callable
collections.Sequence = collections.abc.Sequence

import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
from datetime import datetime

# ==========================================
# CONFIGURAÇÕES DO MONGODB (via Docker)
# ==========================================
# Usando as credenciais do teu docker-compose.yml
#MONGO_URI = "mongodb://root:root@127.0.0.1:27017/"
MONGO_URI = "mongodb://127.0.0.1:27017/"
DB_NAME = "labirinto_db"

# Ligar ao MongoDB
mongo_client = MongoClient(MONGO_URI)
db = mongo_client[DB_NAME]

# Definir as coleções
col_sons = db["sons"]
col_temp = db["temperatura"]
col_mov = db["movimentos"]

# ==========================================
# CONFIGURAÇÕES DO MQTT E FILTRO
# ==========================================
BROKER = "broker.hivemq.com"
PORT = 1883

# Tópicos que a tua app mazerun.exe (labirinto 7) publica
TOPIC_SONS = "pisid_mazesound_7"
TOPIC_TEMP = "pisid_mazetemp_7"
TOPIC_MOV = "pisid_mazemov_7"

# Dicionário para guardar a última mensagem de cada tópico (Filtro de Duplicados)
ultimas_mensagens = {}


# Callback quando o script se liga ao broker
def on_connect(client, userdata, flags, reason_code, properties):
    print(f"✅ Ligado ao broker HiveMQ com sucesso! (Código: {reason_code})")

    # Subscrever aos 3 tópicos com QoS 1 (Garantia de entrega)
    client.subscribe([
        (TOPIC_SONS, 1),
        (TOPIC_TEMP, 1),
        (TOPIC_MOV, 1)
    ])
    print("📡 A escutar mensagens (QoS 1) com filtro de duplicados ativo...")


# Callback quando uma mensagem é recebida
def on_message(client, userdata, msg):
    topico = msg.topic
    payload = msg.payload.decode('utf-8')
    agora = datetime.utcnow()  # Guardamos logo a hora exata em que chegou

    # ==========================================
    # FILTRO DE DUPLICADOS DE REDE
    # ==========================================
    if topico in ultimas_mensagens:
        ultima_msg = ultimas_mensagens[topico]

        # Calcula a diferença de tempo em segundos
        diferenca_tempo = (agora - ultima_msg['tempo']).total_seconds()

        # Se o texto for igual E a diferença for menor que 0.5 segundos
        if payload == ultima_msg['texto'] and diferenca_tempo < 0.5:
            print(f"♻️ Duplicado ignorado no tópico {topico} (chegou {diferenca_tempo:.3f}s depois)")
            return  # Pára a execução aqui, não guarda na base de dados!

    # Atualiza a memória com a nova mensagem válida
    ultimas_mensagens[topico] = {'texto': payload, 'tempo': agora}
    # ==========================================

    print(f"[{topico}] Mensagem recebida: {payload}")

    # Tentar converter a mensagem para JSON
    try:
        dados = json.loads(payload)
    except json.JSONDecodeError:
        # Se for apenas um valor (ex: "25.5")
        dados = {"valor": payload}

    # Preparar o documento a inserir no Mongo
    documento = {
        "topico": topico,
        "dados": dados,
        "data_rececao": agora  # Usamos a mesma hora 'agora' do início da função
    }

    # Encaminhar para a coleção correta dependendo do tópico
    if topico == TOPIC_SONS:
        col_sons.insert_one(documento)
    elif topico == TOPIC_TEMP:
        col_temp.insert_one(documento)
    elif topico == TOPIC_MOV:
        col_mov.insert_one(documento)


# ==========================================
# INICIAR O CLIENTE MQTT
# ==========================================
# A usar a versão 2 da API que é o standard nas versões mais recentes do Paho
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

print("A tentar ligar ao broker...")
client.connect(BROKER, PORT, 60)

# Manter o script a correr para sempre à escuta de mensagens
try:
    client.loop_forever()
except KeyboardInterrupt:
    print("\nScript terminado pelo utilizador.")
    client.disconnect()
    mongo_client.close()