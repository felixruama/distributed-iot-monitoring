import os
import time
import json
import threading
from datetime import datetime # --- ALTERAÇÃO AQUI: Import para validar as datas ---
from dotenv import load_dotenv
from pymongo import MongoClient
import paho.mqtt.client as mqtt
import mysql.connector

load_dotenv() #Vai ler as passwords e IPs escondidos no ficheiro .env (segurança)

# Configurações Iniciais
N_JOGADOR = 7
# --- ALTERAÇÃO AQUI: Mantém a directConnection para não dar o erro do ReplicaSet ---
MONGO_URI = os.getenv("MONGO_URI", "mongodb://root:root@localhost:27017/?directConnection=true")
MONGO_DB = "sensores_db"
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
BATCH_SIZE = 10  # Tamanho do bloco de movimentos --(10 moviemntos)--> MQTT

# Tópicos
TOPIC_MOV = f"pisid_mazemovm_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesoundm_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetempm_{N_JOGADOR}"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

periodicidade = 1.0  # valor default caso não mandem
MARGEM_OUTLIER_TEMP = 5.0  # Se saltar 5ºC de repente face à média, é erro do sensor
MARGEM_OUTLIER_SOM = 20.0  # Se o som saltar 20dB de repente face à média, é erro do sensor
last_ack_id = None
ack_event = threading.Event() #gere a espera entre on envio de movimentos e recepção de ack (semafaro) vermelho=pare=clear , verde=ande=set e wait=fica olhando para a bandeira

# Variáveis globais para validação sacadas da nuvem
max_marsamis_global = 0
lista_corredores_global = []

# --- Aperto de mão entre S1 e MQTT ---
def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] S1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2)
    client.subscribe(TOPIC_CONFIG, qos=2)

def on_message_back(client, userdata, msg):
    global periodicidade, last_ack_id
    try:
        payload = json.loads(msg.payload.decode('utf-8'))

        if msg.topic == TOPIC_ACK:
            last_ack_id = payload.get("last_id")
            ack_event.set()
            print(f"[ACK] Recebido do PC2. Último ID inserido: {last_ack_id}")

        elif msg.topic == TOPIC_CONFIG:
            nova_periodicidade = payload.get("Periodicidade")
            if nova_periodicidade:
                periodicidade = float(nova_periodicidade)
                print(f"[CONFIG] Periodicidade atualizada remotamente para: {periodicidade}s")
    except Exception as e:
        print(f"[MQTT] Erro no processamento da mensagem: {e}")


# Configurar Cliente MQTT
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC1_v3")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message_back
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()

db = MongoClient(MONGO_URI)[MONGO_DB]

# Listas para guardar as últimas 5 medições
historico_som = []
historico_temp = []

def calcular_media(lista):
    if not lista: return 0
    return sum(lista) / len(lista)

def processar_som_temperatura_sec():
    while True:
        try:
            filtro_crus = {
                "Migrado": False,
                "isOutlier": False,
                "Anomalia": False
            }

            for col_name, topic in [("Som", TOPIC_SOM), ("Temperatura", TOPIC_TEMP)]:
                docs = list(db[col_name].find(filtro_crus).limit(50))

                for doc in docs:
                    doc_id = doc["_id"]
                    valor = doc.get("Sound") if col_name == "Som" else doc.get("Temperature")
                    hora = doc.get("Hour")

                    e_anomalia = False
                    e_outlier = False

                    # --- ALTERAÇÃO AQUI: 1. TRATAR ANOMALIAS DE DATA ---
                    if not hora:
                        e_anomalia = True
                        print(f"[ANOMALIA DATA] Lixo detetado em {col_name}: Mensagem sem campo 'Hour'!")
                    else:
                        try:
                            hora_limpa = str(hora).replace('T', ' ')[:19]
                            datetime.strptime(hora_limpa, "%Y-%m-%d %H:%M:%S")
                        except ValueError:
                            e_anomalia = True
                            print(f"[ANOMALIA DATA] Lixo detetado em {col_name}: Data impossível ('{hora}')!")

                    # 2. TRATAR ANOMALIAS DE VALOR
                    if not e_anomalia:
                        try:
                            valor = float(valor)
                            if col_name == "Som" and valor < 0:
                                e_anomalia = True
                                print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é fisicamente possível!")
                            elif col_name == "Temperatura" and (valor < -50 or valor > 150):
                                e_anomalia = True
                                print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é fisicamente possível!")
                        except (ValueError, TypeError):
                            e_anomalia = True
                            print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é numérico!")

                    # 3. TRATAR OUTLIERS
                    if not e_anomalia:
                        lista_historico = historico_som if col_name == "Som" else historico_temp
                        margem_tolerada = MARGEM_OUTLIER_SOM if col_name == "Som" else MARGEM_OUTLIER_TEMP

                        if len(lista_historico) > 0:
                            media_atual = calcular_media(lista_historico)
                            if abs(valor - media_atual) > margem_tolerada:
                                e_outlier = True
                                print(f"[OUTLIER] Bloqueado! {col_name} saltou para {valor} (Média era {media_atual:.1f})")

                        if not e_outlier:
                            lista_historico.append(valor)
                            if len(lista_historico) > 5:
                                lista_historico.pop(0)

                    # REGISTO E ENVIO
                    if e_anomalia:
                        db[col_name].update_one({"_id": doc_id}, {"$set": {"Anomalia": True, "Migrado": False}})
                        continue

                    if e_outlier:
                        db[col_name].update_one({"_id": doc_id}, {"$set": {"isOutlier": True, "Migrado": False}})
                        continue

                    payload = {**doc, "_id": str(doc_id)}
                    mqtt_client.publish(topic, json.dumps(payload), qos=0)

                    db[col_name].update_one({"_id": doc_id}, {"$set": {"Migrado": True}})

        except Exception as e:
            print(f"[THREAD 2] Erro: {e}")

        time.sleep(periodicidade)

# --- MAIN THREAD: Movimentos em Blocos com Handshake (QoS 2) ---
def processar_movimentos_main():
    global last_ack_id
    print("--- Início da Migração de Movimentos por Blocos com Handshake ---")

    while True:
        try:
            filtro_mov = {"Migrado": False, "Anomalia": False}
            batch = list(db.Movimento.find(filtro_mov).sort("Hour", 1).limit(BATCH_SIZE))

            if not batch:
                time.sleep(periodicidade)
                continue

            batch_data = []
            for doc in batch:
                try:
                    # --- ALTERAÇÃO AQUI: Regra 0: Validar a Data primeiro! ---
                    hora = doc.get("Hour")
                    if not hora:
                        raise ValueError("Falta o campo 'Hour' nesta mensagem.")

                    hora_limpa = str(hora).replace('T', ' ')[:19]
                    # Se for data inválida (ex: dia 32), o strptime estoira e vai logo para o except!
                    datetime.strptime(hora_limpa, "%Y-%m-%d %H:%M:%S")

                    marsami_id = int(doc["Marsami"])
                    origem = int(doc["RoomOrigin"])
                    destino = int(doc["RoomDestiny"])

                    # Regra 1: Marsami tem de existir
                    if not (1 <= marsami_id <= max_marsamis_global):
                        raise ValueError(f"Marsami ID {marsami_id} é inválido/não existe.")

                    # Regra 2: O corredor tem de existir (origem 0 é exceção pois é o limbo)
                    if origem != 0:
                        corredor_valido = any(c['Rooma'] == origem and c['Roomb'] == destino for c in lista_corredores_global)
                        if not corredor_valido:
                            raise ValueError(f"O corredor {origem}->{destino} não existe no labirinto!")

                    batch_data.append({**doc, "_id": str(doc["_id"])})

                except ValueError as ve:
                    # Se der erro na data (ValueError do strptime) ou nos int(), cai aqui
                    print(f"[ANOMALIA MOVIMENTO] Lixo detetado: {ve} (Hora: {doc.get('Hour')})")
                    db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Anomalia": True, "Migrado": False}})
                except Exception as err:
                    print(f"[ANOMALIA MOVIMENTO] Erro genérico: {err}")
                    db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Anomalia": True, "Migrado": False}})

            if not batch_data:
                continue

            ids_no_bloco = [d["_id"] for d in batch_data]
            sucesso_bloco = False

            while not sucesso_bloco:
                print(f"[MAIN] Enviando bloco de {len(batch_data)} movimentos válidos...")
                ack_event.clear()
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)

                recebeu_resposta = ack_event.wait(timeout=5.0)

                if not recebeu_resposta:
                    print(f"[MAIN] Timeout! Perguntando ao PC2: Did you get it?")
                    ack_event.clear()
                    ping_payload = {"Player": N_JOGADOR}
                    mqtt_client.publish(TOPIC_PING, json.dumps(ping_payload), qos=2)
                    recebeu_resposta = ack_event.wait(timeout=3.0)

                if recebeu_resposta:
                    if last_ack_id in ids_no_bloco:
                        for doc in batch_data:
                            db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                            if str(doc["_id"]) == last_ack_id:
                                break

                        print(f"[MAIN] Bloco confirmado até {last_ack_id}.")
                        sucesso_bloco = True
                    else:
                        print(f"[MAIN] ID ({last_ack_id}) é antigo. O bloco atual falhou a inserção. Reenviando...")
                else:
                    print("[MAIN] Sem resposta ao ACK nem ao Ping. Tentando reenvio do bloco...")

        except Exception as e:
            print(f"[MAIN] Erro Crítico: {e}")
            time.sleep(5)


def obter_valores_iniciais_nuvem():
    try:
        print("[INIT] A ligar à BD da Nuvem (194.210.86.10) para obter valores normais e estrutura...")
        conexao_nuvem = mysql.connector.connect(
            host="194.210.86.10",
            user="aluno",
            password="aluno",
            database="maze"
        )
        cursor = conexao_nuvem.cursor(dictionary=True)

        cursor.execute("SELECT normaltemperature, normalnoise, numbermarsamis FROM setupmaze LIMIT 1")
        resultado = cursor.fetchone()

        cursor.execute("SELECT Rooma, Roomb FROM corridor")
        corredores = cursor.fetchall()

        if resultado:
            temp_normal = float(resultado['normaltemperature'])
            som_normal = float(resultado['normalnoise'])
            total_mars = int(resultado['numbermarsamis'])
            print(f"[INIT] Valores base obtidos com sucesso: Temp={temp_normal}ºC, Som={som_normal}dB, Marsamis={total_mars}")
            return som_normal, temp_normal, total_mars, corredores
        else:
            print("[INIT] Tabela setupmaze vazia. A assumir defaults.")
            return 20.0, 20.0, 10, corredores

    except Exception as e:
        print(f"[INIT] Erro ao ligar à Nuvem: {e}. A assumir defaults.")
        return 20.0, 20.0, 10, []
    finally:
        if 'conexao_nuvem' in locals() and conexao_nuvem.is_connected():
            cursor.close()
            conexao_nuvem.close()


if __name__ == "__main__":
    som_base, temp_base, max_marsamis_global, lista_corredores_global = obter_valores_iniciais_nuvem()

    historico_som.append(som_base)
    historico_temp.append(temp_base)

    t = threading.Thread(target=processar_som_temperatura_sec, daemon=True)
    t.start()

    processar_movimentos_main()