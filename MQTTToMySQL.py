import os
import time
import json
from dotenv import load_dotenv
import paho.mqtt.client as mqtt
import mysql.connector

# Carregar credenciais locais do PC2 (Pág. 23 do Relatório)
load_dotenv()

N_JOGADOR = 7
MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = 1883

# Credenciais Role Migrador (Pág. 23)
DB_USER = os.getenv("DB_MIGRADOR_USER", "role_migrador")
DB_PASS = os.getenv("DB_MIGRADOR_PASS", "password_migrador")
DB_HOST = "localhost" # Corre na mesma máquina
DB_NAME = "labirinto_db_final"

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_ACTUATOR = "pisid_mazeact"

# Conexão BD
def conectar_bd():
    return mysql.connector.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME
    )

# --- SINGLE-THREAD CALLBACKS (Pág. 10) ---
def on_connect(client, userdata, flags, rc):
    print("[MQTT] S2 Ligado! A escutar mensagens do S1...")
    client.subscribe([(TOPIC_MOV, 2), (TOPIC_SOM, 0), (TOPIC_TEMP, 0), (TOPIC_PING, 2)])

def on_message(client, userdata, msg):
    payload = json.loads(msg.payload.decode('utf-8'))
    
    try:
        db = conectar_bd()
        cursor = db.cursor()
        
        # 1. TRATAMENTO DE MOVIMENTO (Pág. 8 e 9)
        if msg.topic == TOPIC_MOV:
            doc_id = payload.get("_id")
            # Argumentos baseados na SP_RegistarPassagem (Pág. 16)
            # Nota: O ID da simulação atual deve ser obtido da BD
            args = (
                1, # ID Simulação (assumindo 1 para o exemplo)
                payload.get("Marsami"),
                payload.get("RoomOrigin"),
                payload.get("RoomDestiny"),
                payload.get("Status"),
                doc_id
            )
            try:
                cursor.callproc('SP_RegistarPassagem', args)
                db.commit()
                # Enviar ACK de Sucesso (Received: 1)
                resposta = {"Player": N_JOGADOR, "Doc": doc_id, "Received": 1}
                client.publish(TOPIC_ACK, json.dumps(resposta), qos=2)
                print(f"[S2] Passagem registada. ACK 1 enviado para {doc_id}")
            except Exception as err:
                db.rollback()
                print(f"[S2] Erro a inserir movimento: {err}")
                # Enviar ACK de Falha (Received: 0)
                client.publish(TOPIC_ACK, json.dumps({"Player": N_JOGADOR, "Doc": doc_id, "Received": 0}), qos=2)

        # 2. TRATAMENTO DO DID YOU GET IT (Pág. 8 e 9)
        elif msg.topic == TOPIC_PING:
            doc_id = payload.get("Doc")
            print(f"[S2] Recebi pedido didyougetit para {doc_id}. A verificar MySQL...")
            # Verifica se o IDMongo já está na tabela medicoespassagens (Pág. 9)
            cursor.execute("SELECT IDMedicao FROM medicoespassagens WHERE IDMongo = %s", (doc_id,))
            resultado = cursor.fetchone()
            
            status_resposta = 1 if resultado else 0
            resposta = {"Player": N_JOGADOR, "Doc": doc_id, "Received": status_resposta}
            client.publish(TOPIC_ACK, json.dumps(resposta), qos=2)
            print(f"[S2] Resposta ao didyougetit enviada: {resposta}")

        # 3. TRATAMENTO DE ALERTAS SOM/TEMP (Pág. 14)
        elif msg.topic in [TOPIC_SOM, TOPIC_TEMP]:
            tipo_sensor = "Som" if msg.topic == TOPIC_SOM else "Temperatura"
            valor = payload.get("Sound") if msg.topic == TOPIC_SOM else payload.get("Temperature")
            
            # Aqui S2 delega o controlo anti-spam para a SP_RegistarAlerta (Pág. 14)
            # A SP verifica os limites e os tempos de cooldown na tabela simulacao
            args_alerta = (1, tipo_sensor, valor, payload.get("Room", 0)) # ID Simulacao, Tipo, Valor, Sala
            cursor.callproc('SP_RegistarAlerta', args_alerta)
            db.commit()
            
        cursor.close()
        db.close()
        
    except Exception as e:
        print(f"[S2] Erro geral de Base de Dados: {e}")

# Iniciar S2
mqtt_client = mqtt.Client(client_id="Grupo7_S2")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)

print("--- A iniciar Script S2 (Single-Thread) ---")
mqtt_client.loop_forever() # Bloqueia e fica a escutar (Pág. 10)