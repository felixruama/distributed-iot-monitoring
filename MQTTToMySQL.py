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
BATCH_SIZE = 10  # Tamanho do bloco de movimentos

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

# Variáveis globais de controlo
periodicidade = 2.0
last_ack_id = None
ack_event = threading.Event()

# --- CALLBACKS MQTT ---
def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] S1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)

def on_message(client, userdata, msg):
    global periodicidade, last_ack_id
    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        
        if msg.topic == TOPIC_ACK:
            # Resposta do PC2: {"Player": 7, "last_id": "...", "status": 1}
            last_ack_id = payload.get("last_id")
            ack_event.set()
            print(f"[ACK] Recebido do PC2. Último ID inserido: {last_ack_id}")
            
        elif msg.topic == TOPIC_CONFIG:
            nova_periodicidade = payload.get("Periodicidade")
            if nova_periodicidade:
                periodicidade = float(nova_periodicidade)
                print(f"[CONFIG] Periodicidade atualizada: {periodicidade}s")
    except Exception as e:
        print(f"[MQTT] Erro no processamento da mensagem: {e}")

# Configurar Cliente MQTT
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC1_v2")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()

# Ligar ao MongoDB
db = MongoClient(MONGO_URI)[MONGO_DB]

# --- THREAD SECUNDÁRIA: Som e Temperatura (QoS 0) ---
def processar_som_temperatura():
    while True:
        try:
            filtro = {"Migrado": False, "Anomalia": False, "isOutlier": False}
            
            for col_name, topic in [("Som", TOPIC_SOM), ("Temperatura", TOPIC_TEMP)]:
                docs = list(db[col_name].find(filtro).limit(50))
                for doc in docs:
                    payload = {**doc, "_id": str(doc["_id"])}
                    mqtt_client.publish(topic, json.dumps(payload), qos=0)
                    db[col_name].update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                    
        except Exception as e:
            print(f"[THREAD 2] Erro: {e}")
        time.sleep(periodicidade)

# --- MAIN THREAD: Movimentos em Blocos com Handshake (QoS 2) ---
def processar_movimentos_main():
    global last_ack_id
    print("--- Início da Migração de Movimentos por Blocos ---")
    
    while True:
        try:
            # 1. Obter bloco de movimentos não migrados
            filtro_mov = {"Migrado": False, "Anomalia": False}
            batch = list(db.Movimento.find(filtro_mov).sort("Hour", 1).limit(BATCH_SIZE))
            
            if not batch:
                time.sleep(periodicidade)
                continue

            # 2. Preparar e enviar bloco
            batch_data = [{**doc, "_id": str(doc["_id"])} for doc in batch]
            ids_no_bloco = [d["_id"] for d in batch_data]
            
            sucesso_bloco = False
            while not sucesso_bloco:
                print(f"[MAIN] Enviando bloco de {len(batch_data)} movimentos...")
                ack_event.clear()
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)
                
                # 3. Esperar ACK ou Timeout
                if ack_event.wait(timeout=5.0):
                    # Se o PC2 confirmou o último ID do nosso bloco
                    if last_ack_id in ids_no_bloco:
                        # Marcar como migrados no Mongo até ao ID confirmado
                        for doc in batch:
                            db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                            if str(doc["_id"]) == last_ack_id:
                                break
                        print(f"[MAIN] Bloco confirmado até {last_ack_id}.")
                        sucesso_bloco = True
                    else:
                        print(f"[MAIN] ACK recebido ({last_ack_id}) não pertence ao bloco atual. Reenviando...")
                else:
                    # 4. Timeout -> Handshake "didyougetit"
                    print(f"[MAIN] Timeout! Perguntando ao PC2: Did you get it?")
                    ping_payload = {"Player": N_JOGADOR}
                    mqtt_client.publish(TOPIC_PING, json.dumps(ping_payload), qos=2)
                    
                    # Espera mais um pouco pela resposta do didyougetit
                    if ack_event.wait(timeout=3.0):
                        # Se responder ao ping, tratamos como se fosse um ACK normal
                        continue # Volta ao início do 'while not sucesso_bloco' para validar o last_ack_id
                    else:
                        print("[MAIN] Sem resposta ao didyougetit. Tentando reenvio do bloco...")

        except Exception as e:
            print(f"[MAIN] Erro Crítico: {e}")
            time.sleep(5)

if __name__ == "__main__":
    t = threading.Thread(target=processar_som_temperatura, daemon=True)
    t.start()
    processar_movimentos_main()
