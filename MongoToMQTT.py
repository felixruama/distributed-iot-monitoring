import os
import time
import json
import threading
from dotenv import load_dotenv
from pymongo import MongoClient
from bson import ObjectId
import paho.mqtt.client as mqtt
from collections import deque

margem_tolerancia = None
temp_referencia = None
ruido_referencia = None
periodicidade = None

# Buffers para média móvel (Últimas 5 leituras)
buffer_temp = deque(maxlen=5)
buffer_som = deque(maxlen=5)

load_dotenv()

# Configurações Iniciais
N_JOGADOR = 7
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB = "sensores_db"
MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = 1883
BATCH_SIZE = 10

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

last_ack_id = None
ack_event = threading.Event()


# --- CALLBACKS MQTT ---
def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] PC1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)


def on_message(client, userdata, msg):
    global periodicidade, last_ack_id, margem_tolerancia, temp_referencia, ruido_referencia
    try:
        payload = json.loads(msg.payload.decode('utf-8'))

        if msg.topic == TOPIC_ACK:
            last_ack_id = payload.get("last_id")
            ack_event.set()

        elif msg.topic == TOPIC_CONFIG:
            # Atribuição com fallback para valores padrão seguros
            periodicidade = float(payload.get("Periodicidade", 2.0))
            margem_tolerancia = float(payload.get("MargemToleranciaOutlier", 5.0))
            temp_referencia = float(payload.get("normaltemperature", 20.0))
            ruido_referencia = float(payload.get("normalnoise", 50.0))
            print(f"[CONFIG] Parâmetros atualizados via MQTT!")

    except Exception as e:
        print(f"[MQTT] Erro no processamento: {e}")


# Configurar Cliente
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC1_v2")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()

db = MongoClient(MONGO_URI)[MONGO_DB]


def check_qualidade(doc, tipo):
    valor = doc.get("Leitura")
    if valor is None or not isinstance(valor, (int, float)):
        return 'anomalia', None

    buffer = buffer_temp if tipo == "Temperatura" else buffer_som
    ref_inicial = temp_referencia if tipo == "Temperatura" else ruido_referencia

    # Média Móvel (Se buffer vazio, usa referência do MySQL)
    media = sum(buffer) / len(buffer) if buffer else ref_inicial

    if abs(valor - media) > margem_tolerancia:
        return 'outlier', None
    return 'ok', valor


# --- THREAD 2: Sensores (QoS 0 - Fire and Forget) ---
def processar_som_temperatura():
    while True:
        if margem_tolerancia is None or periodicidade is None:
            time.sleep(2)
            continue
        try:
            filtro = {"Migrado": False, "isAnomalia": {"$ne": True}, "isOutlier": {"$ne": True}}
            for col_name, topic in [("Som", TOPIC_SOM), ("Temperatura", TOPIC_TEMP)]:
                docs = list(db[col_name].find(filtro).limit(50))
                for doc in docs:
                    status, valor_validado = check_qualidade(doc, col_name)

                    if status == 'anomalia':
                        db[col_name].update_one({"_id": doc["_id"]}, {"$set": {"isAnomalia": True}})
                        continue
                    if status == 'outlier':
                        db[col_name].update_one({"_id": doc["_id"]}, {"$set": {"isOutlier": True}})
                        continue

                    if col_name == "Temperatura":
                        buffer_temp.append(valor_validado)
                    else:
                        buffer_som.append(valor_validado)

                    # Publica e marca Migrado imediatamente (Sem ACK)
                    payload = {**doc, "_id": str(doc["_id"])}
                    mqtt_client.publish(topic, json.dumps(payload), qos=0)
                    db[col_name].update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
        except Exception as e:
            print(f"[THREAD 2] Erro: {e}")
        time.sleep(periodicidade)


# --- MAIN THREAD: Movimentos (QoS 2 - Handshake Garantido) ---
def processar_movimentos_main():
    global last_ack_id
    print("--- Início da Migração Crítica de Movimentos ---")
    while True:
        if periodicidade is None:
            time.sleep(2)
            continue
        try:
            filtro_mov = {"Migrado": False, "isAnomalia": {"$ne": True}}
            batch = list(db.Movimento.find(filtro_mov).sort("Hour", 1).limit(BATCH_SIZE))

            if not batch:
                time.sleep(periodicidade)
                continue

            batch_data = [{**doc, "_id": str(doc["_id"])} for doc in batch]
            ids_no_bloco = [d["_id"] for d in batch_data]

            sucesso_bloco = False
            while not sucesso_bloco:
                ack_event.clear()
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)

                if ack_event.wait(timeout=5.0):
                    if last_ack_id in ids_no_bloco:
                        for doc in batch:
                            db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                            if str(doc["_id"]) == last_ack_id: break
                        print(f"[MAIN] Bloco migrado até {last_ack_id}.")
                        sucesso_bloco = True
                else:
                    print(f"[MAIN] Timeout. A verificar recepção...")
                    mqtt_client.publish(TOPIC_PING, json.dumps({"Player": N_JOGADOR}), qos=2)
                    time.sleep(2)  # Pausa para resposta do ping

        except Exception as e:
            print(f"[MAIN] Erro: {e}")
            time.sleep(5)


if __name__ == "__main__":
    t = threading.Thread(target=processar_som_temperatura, daemon=True)
    t.start()
    processar_movimentos_main()