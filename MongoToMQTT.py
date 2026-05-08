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
TOPIC_RESEND = f"pisid_resend_{N_JOGADOR}" # --- NOVO TÓPICO ---

periodicidade = 1.0
MARGEM_OUTLIER_TEMP = 5.0
MARGEM_OUTLIER_SOM = 20.0
last_ack_id = None
ack_event = threading.Event()
pedido_resend = False # --- FLAG GLOBAL DA TUA ESTRATÉGIA ---

max_marsamis_global = 0
lista_corredores_global = []

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] S1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)
    client.subscribe(TOPIC_RESEND, qos=2) # PC1 ouve o pedido de resend


def on_message_back(client, userdata, msg):
    global periodicidade, last_ack_id, pedido_resend
    try:
        payload = json.loads(msg.payload.decode('utf-8'))

        if msg.topic == TOPIC_ACK:
            last_ack_id = payload.get("last_id")
            ack_event.set()
            print(f"[ACK] Recebido do PC2. Último ID inserido: {last_ack_id}")

        elif msg.topic == TOPIC_RESEND:
            last_ack_id = payload.get("last_id")
            pedido_resend = True # Ativa a tua estratégia
            ack_event.set() # Desbloqueia o main loop imediatamente
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
                id_esperado = ids_no_bloco[-1] # Este é o ID que prova que o bloco todo foi entregue

                print(f"\n[MAIN] A publicar bloco de {len(batch_data)} movimentos...")
                ack_event.clear()
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)

                # Ciclo interior que só destranca quando o bloco for resolvido
                while not sucesso_bloco:
                    recebeu_resposta = ack_event.wait(timeout=6.0)

                    # 1. Se não recebeu resposta (PC2 demorado ou morto) -> PING
                    if not recebeu_resposta:
                        print("[MAIN] Timeout! O PC2 está demorado. A interrogar com Ping...")
                        ack_event.clear()
                        mqtt_client.publish(TOPIC_PING, json.dumps({"Player": N_JOGADOR}), qos=2)
                        continue # Volta ao inicio do while interior para ficar à espera do Ping

                    # Se o código chega aqui, é porque chegou um ACK ou um pedido de RESEND
                    ack_event.clear()

                    # 2. CORTA-MATO: O PC2 morreu e ressuscitou a gritar RESEND!
                    if pedido_resend:
                        pedido_resend = False
                        if last_ack_id in ids_no_bloco:
                            index = ids_no_bloco.index(last_ack_id)
                            # Marca como feito o que ele conseguiu guardar antes de morrer
                            for i in range(index + 1):
                                db.Movimento.update_one({"_id": ObjectId(batch_data[i]["_id"])}, {"$set": {"Migrado": True}})

                            if index == len(batch_data) - 1:
                                print("[MAIN] PÓS-CRASH: O PC2 já tinha guardado tudo antes de cair. Avançando...")
                                sucesso_bloco = True
                            else:
                                print(f"[MAIN] PÓS-CRASH: Cortando bloco. A reenviar os {len(batch_data) - (index + 1)} itens que ele perdeu no crash...")
                                batch_data = batch_data[index + 1:]
                                break # Quebra o while interior para REPUBLICAR o bloco cortado
                        else:
                            print("[MAIN] PÓS-CRASH: O PC2 não tinha nenhum dado deste bloco. A reenviar bloco inteiro...")
                            break # Quebra o while interior para REPUBLICAR o bloco inteiro

                    # 3. MODO NORMAL: Avaliar as respostas do ACK e Ping
                    else:
                        if last_ack_id == id_esperado:
                            # O ID do ACK bate certo com o fim do nosso pacote = Sucesso Total
                            for doc in batch_data:
                                db.Movimento.update_one({"_id": ObjectId(doc["_id"])}, {"$set": {"Migrado": True}})
                            print(f"[MAIN] SUCESSO! Bloco concluído até {last_ack_id}.")
                            sucesso_bloco = True
                        else:
                            # O PC2 está vivo, mas está atrasado (o ACK recebido é antigo).
                            print(f"[MAIN] PC2 vivo no ID {last_ack_id}, mas queremos {id_esperado}. A aguardar...")
                            time.sleep(2)
                            # Volta ao inicio do loop interior e espera de novo (se não houver ACK natural, ele manda Ping)

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