import os
import time
import json
import mysql.connector
import paho.mqtt.client as mqtt
from mysql.connector import errorcode

# ==========================================
# CONFIGURAÇÕES INICIAIS
# ==========================================
N_JOGADOR = 7
MYSQL_CONFIG = {
    'user': 'root',
    'password': '',
    'host': 'localhost',
    'database': 'pisid_db'
}
MQTT_BROKER = "localhost"
MQTT_PORT = 1883

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

# Variáveis Globais de Controlo
db_conn = None
id_simulacao_ativa = None
last_inserted_id = None

# ==========================================
# GESTÃO DE BASE DE DADOS (LIGAÇÃO PERSISTENTE)
# ==========================================
def obter_db():
    """MUDANÇA: Mantém a ligação aberta para evitar overhead de rede/CPU"""
    global db_conn
    if db_conn is None or not db_conn.is_connected():
        try:
            db_conn = mysql.connector.connect(**MYSQL_CONFIG)
            print("[DB] Ligação persistente estabelecida.")
        except mysql.connector.Error as err:
            print(f"[ERRO DB] Falha ao ligar: {err}")
            return None
    return db_conn

def atualizar_id_simulacao():
    """MUDANÇA: Procura a simulação iniciada (Estado 1) automaticamente"""
    global id_simulacao_ativa
    db = obter_db()
    if db:
        try:
            cursor = db.cursor()
            cursor.execute("SELECT IDSimulacao FROM simulacao WHERE Estado = '1' LIMIT 1")
            res = cursor.fetchone()
            cursor.close()
            if res:
                id_simulacao_ativa = res[0]
                print(f"[SIMULAÇÃO] Ativa detetada: ID {id_simulacao_ativa}")
            else:
                id_simulacao_ativa = None
                print("[AVISO] Nenhuma simulação ativa (Estado=1) encontrada.")
        except mysql.connector.Error as err:
            print(f"[ERRO SQL] {err}")

# ==========================================
# CALLBACKS MQTT
# ==========================================
def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] PC2 Ligado (Código: {rc})")
    client.subscribe([(TOPIC_MOV, 2), (TOPIC_TEMP, 1), (TOPIC_SOM, 1), (TOPIC_PING, 2)])
    atualizar_id_simulacao()

def on_message(client, userdata, msg):
    global last_inserted_id, id_simulacao_ativa

    db = obter_db()
    if not db: return

    # MUDANÇA: Se a simulação ativa for desconhecida, tenta atualizar
    if id_simulacao_ativa is None:
        atualizar_id_simulacao()
        if id_simulacao_ativa is None: return

    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        cursor = db.cursor()

        # 1. TRATAMENTO DOS MOVIMENTOS (PROCESSO POR BLOCO)
        if msg.topic == TOPIC_MOV:
            print(f"\n[MOV] Recebido bloco de {len(payload)} registos.")
            sucesso_bloco = True

            for mov in payload:
                try:
                    # MUDANÇA: Passa o ID dinâmico da simulação em curso
                    cursor.callproc('SP_RegistarPassagem', [
                        id_simulacao_ativa,
                        mov['Marsami'],
                        mov['RoomOrigin'],
                        mov['RoomDestiny'],
                        mov['Status'],
                        mov['_id']
                    ])
                    last_inserted_id = mov['_id']
                except mysql.connector.Error as err:
                    print(f"[SQL] Erro no movimento {mov['_id']}: {err}")
                    sucesso_bloco = False
                    break # Interrompe o bloco para manter a ordem cronológica

            if sucesso_bloco:
                db.commit()
                # Responde com o último ID gravado com sucesso no bloco
                ack_payload = {"Player": N_JOGADOR, "last_id": last_inserted_id, "status": 1}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
                print(f"[ACK] Bloco gravado. Último ID: {last_inserted_id}")
            else:
                db.rollback()

        # 2. TRATAMENTO DO PING ("DID YOU GET IT?")
        elif msg.topic == TOPIC_PING:
            print(f"\n[PING] S1 perguntou o último ID. A consultar BD...")
            try:
                # MUDANÇA: Consulta o último IDMongo realmente gravado na BD
                cursor.execute("SELECT IDMongo FROM medicoespassagens ORDER BY IDMedicao DESC LIMIT 1")
                resultado = cursor.fetchone()
                id_real_na_bd = resultado[0] if resultado else None

                print(f"[PING] A BD confirmou que o último ID é: {id_real_na_bd}")

                ack_payload = {"Player": N_JOGADOR, "last_id": id_real_na_bd, "status": 1}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
            except mysql.connector.Error as err:
                print(f"[ERRO PING] {err}")

        # 3. TRATAMENTO DE ALERTAS (SOM E TEMPERATURA)
        elif msg.topic in [TOPIC_TEMP, TOPIC_SOM]:
            val = payload.get('Temperature') or payload.get('Sound')
            sensor_type = 'T' if 'Temperature' in payload else 'S'
            sala = payload.get('RoomOrigin', 0)

            # MUDANÇA: Mantida a SP_RegistarAlerta conforme pedido
            cursor.callproc('SP_RegistarAlerta', [id_simulacao_ativa, sensor_type, val, sala])
            db.commit()
            print(f"[SENSOR] Alerta processado ({sensor_type}): {val}")

        cursor.close()

    except Exception as e:
        print(f"[ERRO CRÍTICO] {e}")

# ==========================================
# INICIALIZAÇÃO
# ==========================================
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC2_Monitor", clean_session=False)
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message

print("A tentar ligar ao broker...")
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)

print("--- PC2: Monitor de Migração Ativo (Ligação Persistente + Blocos) ---")
mqtt_client.loop_forever()