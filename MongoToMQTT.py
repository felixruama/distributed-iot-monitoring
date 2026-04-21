import os
import time
import json
import threading
from dotenv import load_dotenv
from pymongo import MongoClient
import paho.mqtt.client as mqtt

# Carregar credenciais (Pág. 23 do Relatório)
load_dotenv()

# Configurações Iniciais
N_JOGADOR = 7
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB = "sensores_db"
MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = 1883

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

# Variáveis globais de controlo (Pág. 7 e 8)
periodicidade = 2.0  # Pode ser alterada via MQTT config
acks_pendentes = {}  # Guarda o status do ACK recebido { 'id_mongo': 1 ou 0 }

# --- CALLBACKS MQTT ---
def on_connect(client, userdata, flags, rc):
    print("[MQTT] S1 Ligado ao Broker!")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)

def on_message(client, userdata, msg):
    global periodicidade, acks_pendentes
    payload = json.loads(msg.payload.decode('utf-8'))
    
    if msg.topic == TOPIC_ACK:
        # Recebeu resposta do PC2 (Pág. 8)
        doc_id = payload.get("Doc")
        status = payload.get("Received")
        acks_pendentes[doc_id] = status
        
    elif msg.topic == TOPIC_CONFIG:
        # Atualização dinâmica da periodicidade em RAM (Pág. 7)
        nova_periodicidade = payload.get("Periodicidade")
        if nova_periodicidade:
            periodicidade = nova_periodicidade
            print(f"[CONFIG] Periodicidade alterada para {periodicidade}s")

# Configurar Cliente MQTT
mqtt_client = mqtt.Client(client_id="Grupo7_S1")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start() # Thread em background para escutar respostas (Pág. 10)

# Ligar ao MongoDB
db = MongoClient(MONGO_URI)[MONGO_DB]

# --- THREAD SECUNDÁRIA: Som e Temperatura (Pág. 10 e 11) ---
def processar_som_temperatura():
    while True:
        try:
            # Filtrar documentos não migrados, não anómalos e não outliers (Pág. 12 e 13)
            filtro = {"Migrado": False, "Anomalia": False, "isOutlier": False}
            
            # Processar Som
            para_som = list(db.Som.find(filtro).limit(50))
            for doc in para_som:
                doc_str = {**doc, "_id": str(doc["_id"])}
                # QoS 0 para Som e Temperatura (Pág. 11)
                mqtt_client.publish(TOPIC_SOM, json.dumps(doc_str), qos=0)
                db.Som.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
            
            # Processar Temperatura
            para_temp = list(db.Temperatura.find(filtro).limit(50))
            for doc in para_temp:
                doc_str = {**doc, "_id": str(doc["_id"])}
                mqtt_client.publish(TOPIC_TEMP, json.dumps(doc_str), qos=0)
                db.Temperatura.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                
        except Exception as e:
            print(f"[THREAD 2] Erro: {e}")
            
        time.sleep(periodicidade)

# --- MAIN THREAD: Movimentos com Handshake (Pág. 8 e 9) ---
def processar_movimentos_main():
    print("--- A iniciar Migração de Movimentos (Main) ---")
    while True:
        try:
            # Encontra o próximo movimento pendente respeitando a ordem
            filtro_mov = {"Migrado": False, "Anomalia": False}
            doc = db.Movimento.find_one(filtro_mov, sort=[("Hour", 1)])
            
            if not doc:
                time.sleep(periodicidade)
                continue

            doc_id = str(doc["_id"])
            doc_str = {**doc, "_id": doc_id}
            acks_pendentes[doc_id] = None # Reset ao estado do ACK
            
            sucesso = False
            while not sucesso:
                print(f"[MAIN] A enviar movimento {doc_id}...")
                # QoS 2 para Movimentos (Pág. 11)
                mqtt_client.publish(TOPIC_MOV, json.dumps(doc_str), qos=2)
                
                # Timeout à espera do ACK (Pág. 8)
                timeout_espera = 5
                tempo_inicial = time.time()
                
                while acks_pendentes[doc_id] is None and (time.time() - tempo_inicial) < timeout_espera:
                    time.sleep(0.5)
                
                # Análise da Resposta
                if acks_pendentes[doc_id] == 1:
                    db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                    print(f"[MAIN] Confirmação recebida! {doc_id} migrado.")
                    sucesso = True
                    
                elif acks_pendentes[doc_id] == 0:
                    print(f"[MAIN] PC2 diz que falhou a inserção (Received=0). A reenviar...")
                    acks_pendentes[doc_id] = None
                    time.sleep(1)
                    
                else:
                    # Tempo expirou sem resposta, fazer "Did you get it?" (Pág. 8 e 9)
                    print(f"[MAIN] Timeout! A enviar didyougetit para o documento {doc_id}...")
                    ping_payload = {"Player": N_JOGADOR, "Doc": doc_id}
                    mqtt_client.publish(TOPIC_PING, json.dumps(ping_payload), qos=2)
                    time.sleep(2) # Espera 2 segundos para dar tempo ao PC2 de responder ao ping
                    
        except Exception as e:
            print(f"[MAIN] Erro Crítico: {e}")
            time.sleep(5)

if __name__ == "__main__":
    # Iniciar thread secundária para Som e Temp
    t = threading.Thread(target=processar_som_temperatura, daemon=True)
    t.start()
    
    # Executar lógica crítica no Main
    processar_movimentos_main()