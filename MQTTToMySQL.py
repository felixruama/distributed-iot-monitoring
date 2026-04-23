import os
import json
import mysql.connector
import paho.mqtt.client as mqtt

# Configurações Iniciais
N_JOGADOR = 7
MYSQL_CONFIG = {
    'user': 'root',
    'password': '',
    'host': 'localhost',
    'database': 'pisid_db'  # Ajusta para o nome exato da vossa BD
}
MQTT_BROKER = "localhost"
MQTT_PORT = 1883

# Tópicos
TOPIC_MOV = f"pisid_mazemov_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesound_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetemp_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"

# Estado Global (usado apenas para o bloco atual)
last_inserted_id = None


def get_db_connection():
    return mysql.connector.connect(**MYSQL_CONFIG)


def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] PC2 Ligado (Código: {rc})")
    client.subscribe([(TOPIC_MOV, 2), (TOPIC_TEMP, 1), (TOPIC_SOM, 1), (TOPIC_PING, 2)])


def on_message(client, userdata, msg):
    global last_inserted_id
    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. TRATAMENTO DOS MOVIMENTOS (BLOCO)
        if msg.topic == TOPIC_MOV:
            print(f"\n[MOV] Recebido bloco de {len(payload)} registos.")
            for mov in payload:
                try:
                    # Chamar a vossa Stored Procedure
                    cursor.callproc('SP_RegistarPassagem', [
                        1,  # id_simulacao
                        mov['Marsami'],
                        mov['RoomOrigin'],
                        mov['RoomDestiny'],
                        mov['Status'],
                        mov['_id']
                    ])
                    last_inserted_id = mov['_id']
                except mysql.connector.Error as err:
                    print(f"[SQL] Erro no movimento {mov['_id']}: {err}")
                    # Para o loop se der erro num registo.
                    # Garante que não ficam "buracos" no meio do bloco.
                    break

            conn.commit()

            # Enviar ACK normal após gravar o bloco
            ack_payload = {"Player": N_JOGADOR, "last_id": last_inserted_id, "status": 1}
            client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
            print(f"[ACK] Enviado para o bloco. Último sucesso guardado: {last_inserted_id}")

        # 2. TRATAMENTO DO PING ("DID YOU GET IT?")
        elif msg.topic == TOPIC_PING:
            print(f"\n[PING] Pedido de handshake recebido do S1. A consultar a BD...")
            try:
                # OTIMIZAÇÃO: O S2 vai sempre ler a base de dados em vez da RAM para responder!
                # ATENÇÃO: Confirma se o nome da tabela é "medicoespassagens" e a coluna do Mongo é "IDMongo"
                cursor.execute("SELECT IDMongo FROM medicoespassagens ORDER BY IDMedicao DESC LIMIT 1")
                resultado = cursor.fetchone()

                # Se houver registos, pega no ID; se a tabela estiver vazia, devolve None
                id_real_na_bd = resultado[0] if resultado else None

                print(f"[PING] A BD confirmou que o último ID gravado foi: {id_real_na_bd}")

                # Responde ao S1 com a verdade absoluta da BD
                ack_payload = {"Player": N_JOGADOR, "last_id": id_real_na_bd, "status": 1}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)

            except mysql.connector.Error as err:
                print(f"[ERRO BD PING] {err}")

        # 3. TRATAMENTO DE ALERTAS (SOM E TEMPERATURA)
        elif msg.topic in [TOPIC_TEMP, TOPIC_SOM]:
            val = payload.get('Temperature') or payload.get('Sound')
            sensor_type = 'T' if 'Temperature' in payload else 'S'

            # Delega tudo para a SP_RegistarAlerta
            cursor.callproc('SP_RegistarAlerta', [1, sensor_type, val, 0])
            conn.commit()
            print(f"[SENSOR] Registo de alerta processado ({sensor_type}): {val}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"[ERRO CRÍTICO] Falha na receção/processamento: {e}")


# Inicialização do Cliente
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC2_Monitor", clean_session=False)
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)

print("--- PC2: Monitor de Migração Ativo (Versão Otimizada BD) ---")
mqtt_client.loop_forever()