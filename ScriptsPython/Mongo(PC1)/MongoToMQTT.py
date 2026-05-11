import os
import time
import json
import threading
import argparse
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
import paho.mqtt.client as mqtt
import mysql.connector
from bson.objectid import ObjectId

parser = argparse.ArgumentParser(description="Script: Mongo to MQTT")
parser.add_argument('--broker', type=str, default="broker.hivemq.com", help="Endereço do Broker MQTT")
parser.add_argument('--mongo', type=str, default="mongodb://localhost:27017/?directConnection=true", help="URI do MongoDB")
args = parser.parse_args()

db = MongoClient(args.mongo)["sensores_db"]
mqtt_client = mqtt.Client(client_id="Grupo7_PC1_migrador")

N_JOGADOR = 7
BATCH_SIZE = 10

historico_som = []
historico_temp = []

TOPIC_MOV = f"pisid_mazemovm_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesoundm_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetempm_{N_JOGADOR}"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"
TOPIC_RESEND = f"pisid_resend_{N_JOGADOR}"

periodicidade = 1.0
MARGEM_OUTLIER_TEMP = 5.0
MARGEM_OUTLIER_SOM = 20.0
last_ack_id = None
status_recebido = "OK" # <--- Variável Adicionada
ack_event = threading.Event()
pedido_resend = False

max_marsamis_global = 0
lista_corredores_global = []

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] PC1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)
    client.subscribe(TOPIC_RESEND, qos=2)

def on_message_back(client, userdata, msg):
    global periodicidade, last_ack_id, pedido_resend, status_recebido
    try:
        payload = json.loads(msg.payload.decode('utf-8'))

        if msg.topic == TOPIC_ACK:
            last_ack_id = payload.get("last_id")
            status_recebido = payload.get("status", "OK") # <--- Apanha o estado da BD
            ack_event.set()
            print(f"[ACK] Recebido do PC2. Último ID: {last_ack_id} | Status: {status_recebido}")

        elif msg.topic == TOPIC_RESEND:
            last_ack_id = payload.get("last_id")
            pedido_resend = True
            ack_event.set()
            print(f"[RESEND] O PC2 reiniciou! Último ID sobrevivente no MySQL: {last_ack_id}")

        elif msg.topic == TOPIC_CONFIG:
            nova_periodicidade = payload.get("Periodicidade")
            if nova_periodicidade:
                periodicidade = float(nova_periodicidade)
                print(f"[CONFIG] Periodicidade atualizada remotamente para: {periodicidade}s")
    except Exception as e:
        print(f"[MQTT] Erro no processamento da mensagem: {e}")

mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message_back

broker_address = args.broker.split(':')[0]
broker_port = int(args.broker.split(':')[1]) if ':' in args.broker else 1883

mqtt_client.connect(broker_address, broker_port, 60)
mqtt_client.loop_start()

def calcular_media(lista):
    if not lista: return 0
    return sum(lista) / len(lista)

def processar_som_temperatura_sec():
    while True:
        try:
            filtro_crus = {"Migrado": False, "isOutlier": False, "Anomalia": False}
            for col_name, topic in [("Som", TOPIC_SOM), ("Temperatura", TOPIC_TEMP)]:
                docs = list(db[col_name].find(filtro_crus).limit(50))
                for doc in docs:
                    doc_id = doc["_id"]
                    valor = doc.get("Sound") if col_name == "Som" else doc.get("Temperature")
                    e_anomalia, e_outlier = False, False

                    try:
                        valor = float(valor)
                        if col_name == "Som" and valor < 0: e_anomalia = True
                        elif col_name == "Temperatura" and (valor < -50 or valor > 150): e_anomalia = True
                    except (ValueError, TypeError):
                        e_anomalia = True

                    if not e_anomalia:
                        lista_historico = historico_som if col_name == "Som" else historico_temp
                        margem_tolerada = MARGEM_OUTLIER_SOM if col_name == "Som" else MARGEM_OUTLIER_TEMP
                        if len(lista_historico) > 0:
                            media_atual = calcular_media(lista_historico)
                            if abs(valor - media_atual) > margem_tolerada: e_outlier = True
                        if not e_outlier:
                            lista_historico.append(valor)
                            if len(lista_historico) > 5: lista_historico.pop(0)

                    if e_anomalia:
                        db[col_name].update_one({"_id": doc_id}, {"$set": {"Anomalia": True}}); continue
                    if e_outlier:
                        db[col_name].update_one({"_id": doc_id}, {"$set": {"isOutlier": True}}); continue

                    payload = {**doc, "_id": str(doc_id)}
                    mqtt_client.publish(topic, json.dumps(payload), qos=0)
                    db[col_name].update_one({"_id": doc_id}, {"$set": {"Migrado": True}})
        except Exception as e:
            pass
        time.sleep(periodicidade)

# --- MAIN THREAD: A TUA LÓGICA MESTRA ---
def processar_movimentos_main():
    global last_ack_id, pedido_resend
    print("--- Início da Migração com Estratégia de Reconciliação (Sem Duplicados) ---")

    # =================================================================
    # PASSO 1: HANDSHAKE INICIAL
    # =================================================================
    print("[INIT] A iniciar Handshake de Sincronização com o PC2...")
    sync_concluido = False
    while not sync_concluido:
        ack_event.clear()
        mqtt_client.publish(TOPIC_PING, json.dumps({"Player": N_JOGADOR}), qos=2)
        recebeu_resposta = ack_event.wait(timeout=5.0)

        if recebeu_resposta:
            if last_ack_id is not None:
                try:
                    resultado = db.Movimento.update_many(
                        {"_id": {"$lte": ObjectId(last_ack_id)}, "Migrado": False},
                        {"$set": {"Migrado": True}}
                    )
                    print(f"[INIT] Handshake Concluído! O PC2 já tinha até ao ID {last_ack_id}.")
                    print(f"[INIT] Foram corrigidos {resultado.modified_count} documentos desfasados no MongoDB.")
                except Exception as e:
                    print(f"[INIT] Erro a alinhar BD no arranque: {e}")
            else:
                print("[INIT] Handshake Concluído! O PC2 não tem registos.")
            sync_concluido = True
        else:
            print("[INIT] O PC2 não está a responder (ou MySQL em baixo). A tentar de novo em 5s...")
            time.sleep(5)

    # =================================================================
    # PASSO 2: LOOP DE MIGRAÇÃO
    # =================================================================
    while True:
        try:
            filtro_mov = {"Migrado": False, "Anomalia": False}
            batch = list(db.Movimento.find(filtro_mov).sort("_id", 1).limit(BATCH_SIZE))

            if not batch:
                time.sleep(periodicidade)
                continue

            batch_data = []
            for doc in batch:
                try:
                    marsami_id = int(doc["Marsami"])
                    origem, destino = int(doc["RoomOrigin"]), int(doc["RoomDestiny"])
                    if not (1 <= marsami_id <= max_marsamis_global): raise ValueError("Marsami inválido")
                    if origem != 0:
                        if not any(c['Rooma'] == origem and c['Roomb'] == destino for c in lista_corredores_global):
                            raise ValueError("Corredor inválido")
                    batch_data.append({**doc, "_id": str(doc["_id"])})
                except Exception as err:
                    db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Anomalia": True, "Migrado": True}})

            if not batch_data: continue

            sucesso_bloco = False

            while not sucesso_bloco:
                ids_no_bloco = [d["_id"] for d in batch_data]
                id_esperado = ids_no_bloco[-1]

                print(f"\n[MAIN] A publicar bloco de {len(batch_data)} movimentos...")
                ack_event.clear()
                status_recebido = "OK"
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)

                while not sucesso_bloco:
                    recebeu_resposta = ack_event.wait(timeout=6.0)

                    # 1. Se falhou (Timeout ou Crash na BD), pedimos a verdade ao PC2 (PING)
                    if not recebeu_resposta or status_recebido == "ERROR_DB":
                        print("[MAIN] Timeout ou ERROR_DB! O PC2 falhou a inserção. A interrogar com Ping...")
                        ack_event.clear()
                        mqtt_client.publish(TOPIC_PING, json.dumps({"Player": N_JOGADOR}), qos=2)
                        time.sleep(2)
                        continue

                    ack_event.clear()

                    # =================================================================
                    # AVALIAÇÃO UNIVERSAL DO ESTADO DA BD
                    # =================================================================
                    if last_ack_id == id_esperado:
                        # SUCESSO TOTAL
                        for doc in batch_data:
                            db.Movimento.update_one({"_id": ObjectId(doc["_id"])}, {"$set": {"Migrado": True}})
                        print(f"[MAIN] SUCESSO! Bloco concluído até {last_ack_id}.")
                        sucesso_bloco = True
                        pedido_resend = False

                    elif last_ack_id in ids_no_bloco:
                        # COMMIT PARCIAL DA BD (Muito raro, mas protegido!)
                        index = ids_no_bloco.index(last_ack_id)
                        for i in range(index + 1):
                            db.Movimento.update_one({"_id": ObjectId(batch_data[i]["_id"])}, {"$set": {"Migrado": True}})

                        print(f"[MAIN] RECUPERAÇÃO: A BD guardou apenas até {last_ack_id}. Cortando o bloco...")
                        batch_data = batch_data[index + 1:]
                        pedido_resend = False
                        break # Republica só a segunda metade do bloco

                    else:
                        # ROLLBACK TOTAL
                        print(f"[MAIN] ROLLBACK OU FALHA: O PC2 tem o ID {last_ack_id}, queríamos o {id_esperado}.")
                        print("[MAIN] O bloco não entrou na BD. A reenviar na totalidade...")
                        pedido_resend = False
                        time.sleep(2)
                        break # Republica o bloco inteiro novamente

        except Exception as e:
            print(f"[MAIN] Erro Crítico: {e}")
            time.sleep(5)

def obter_valores_iniciais_nuvem():
    try:
        print("[INIT] A ligar à BD da Nuvem (194.210.86.10) para obter valores normais e estrutura...")
        conexao_nuvem = mysql.connector.connect(host="194.210.86.10", user="aluno", password="aluno", database="maze")
        cursor = conexao_nuvem.cursor(dictionary=True)
        cursor.execute("SELECT normaltemperature, normalnoise, numbermarsamis FROM setupmaze LIMIT 1")
        resultado = cursor.fetchone()
        cursor.execute("SELECT Rooma, Roomb FROM corridor")
        corredores = cursor.fetchall()
        if resultado:
            return float(resultado['normalnoise']), float(resultado['normaltemperature']), int(resultado['numbermarsamis']), corredores
        else: return 20.0, 20.0, 10, corredores
    except Exception as e: return 20.0, 20.0, 10, []

if __name__ == "__main__":
    som_base, temp_base, max_marsamis_global, lista_corredores_global = obter_valores_iniciais_nuvem()
    historico_som.append(som_base); historico_temp.append(temp_base)
    threading.Thread(target=processar_som_temperatura_sec, daemon=True).start()
    processar_movimentos_main()