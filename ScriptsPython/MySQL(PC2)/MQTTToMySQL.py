import os
import json
import mysql.connector
import paho.mqtt.client as mqtt
import argparse # Importado para ler argumentos da consola
from datetime import datetime
import time
from dotenv import load_dotenv

pasta_atual = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(pasta_atual, "..", ".env")) #pip install python-dotenv

parser = argparse.ArgumentParser(description="Script: MQTT to MySQL")
parser.add_argument('--broker', type=str, default="broker.hivemq.com", help="Endereço do Broker MQTT")
args = parser.parse_args()


# Configurações Iniciais
N_JOGADOR = 7
MYSQL_CONFIG = {
    'host': os.getenv('DB_LOCAL_HOST', 'localhost'),
    'user': os.getenv('DB_LOCAL_USER'),
    'password': os.getenv('DB_LOCAL_PASS'),
    'database': os.getenv('DB_LOCAL_NAME', 'labirinto_DB')
}

# Tópicos
TOPIC_MOV = f"pisid_mazemovm_{N_JOGADOR}"
TOPIC_SOM = f"pisid_mazesoundm_{N_JOGADOR}"
TOPIC_TEMP = f"pisid_mazetempm_{N_JOGADOR}"
TOPIC_ACK = f"pisid_response_{N_JOGADOR}"
TOPIC_PING = f"pisid_didyougetit_{N_JOGADOR}"
TOPIC_RESEND = f"pisid_resend_{N_JOGADOR}"
TOPIC_ACTUATORS = "pisid_mazeact"
TOPIC_CONFIG = f"pisid_config_{N_JOGADOR}"

# Estado Global
last_inserted_id = None
db_conn = None
db_cursor = None
id_simulacao_atual = None
motivo = None
jadeuprint = False

limites_alerta = {'temp_max': None, 'temp_min': None, 'som_max': None}
limites_termino = {'temp_max': None, 'temp_min': None, 'som_max': None}

# --- VARIÁVEIS DE ATUADORES ---
ocupacao_memoria = {}
historico_corredores = {}
portas_fechadas = False
estado_ac = None
DELTA_MAXIMO = 5
margemAlertaSom = 0
margemAlertaTemp = 0

def mensagem_recente(hora_str):
    """ Filtro Temporal Delta (Tolerância a Falhas) """
    if not hora_str: return True # Movimentos passam sempre para calcular o Score!
    try:
        # Cortar os microsegundos que o Mazerun envia para não dar erro
        hora_limpa = hora_str.split('.')[0]
        msg_time = datetime.strptime(hora_limpa, "%Y-%m-%d %H:%M:%S")
        delta = (datetime.now() - msg_time).total_seconds()
        return abs(delta) <= DELTA_MAXIMO
    except:
        return False

def verificar_sensores_atuadores(client, sensor_type, valor):
    global portas_fechadas, historico_corredores, estado_ac, margemAlertaSom, margemAlertaTemp
    
    if sensor_type == 'T':
        t_max = limites_alerta['temp_max'] - margemAlertaTemp
        t_min = limites_alerta['temp_min'] + margemAlertaTemp

        # 1. Está muito calor -> LIGA O AC
        if limites_alerta['temp_max'] is not None and valor > t_max and estado_ac != 'ON':
            msg = f"{{Type: AcOn, Player: {N_JOGADOR}}}"
            client.publish(TOPIC_ACTUATORS, msg, qos=1)
            estado_ac = 'ON'
            print(f"[ATUADOR] Ar Condicionado LIGADO (Ativado aos {valor}ºC)")
            
        # 2. A temperatura já desceu para um valor seguro (ex: 2 graus abaixo do t_max) -> DESLIGA O AC
        elif limites_alerta['temp_max'] is not None and valor <= (t_max - 2) and estado_ac == 'ON':
            msg = f"{{Type: AcOff, Player: {N_JOGADOR}}}"
            client.publish(TOPIC_ACTUATORS, msg, qos=1)
            estado_ac = 'OFF'
            print(f"[ATUADOR] Ar Condicionado DESLIGADO (Temperatura normalizou para {valor}ºC)")

        # 3. Proteção Contra Frio Extremo: O labirinto está a congelar naturalmente -> GARANTE AC DESLIGADO
        elif limites_alerta['temp_min'] is not None and valor < t_min and estado_ac != 'OFF':
            msg = f"{{Type: AcOff, Player: {N_JOGADOR}}}"
            client.publish(TOPIC_ACTUATORS, msg, qos=1)
            estado_ac = 'OFF'
            print(f"[ATUADOR] Ar Condicionado DESLIGADO por segurança (Muito frio: {valor}ºC)")
            
    elif sensor_type == 'S':
        if limites_alerta['som_max'] is not None:
            s_max = limites_alerta['som_max'] - margemAlertaSom
            if valor > s_max:
                # O som está alto! MODO EXTREMO
                if not portas_fechadas:
                    try:
                        # 1. Tranca na Base de Dados LOCAL
                        db_cursor.execute("UPDATE corredor SET Aberto = 0 WHERE IDSimulacao = %s", (id_simulacao_atual,))
                        db_conn.commit()
                        portas_fechadas = True 
                        
                        # 2. Dispara o super-comando MQTT
                        msg = f"{{Type: CloseAllDoor, Player: {N_JOGADOR}}}"
                        client.publish(TOPIC_ACTUATORS, msg, qos=1)
                        
                        print(f"[ATUADOR SOM] Nível de som crítico ({valor}dB). Todas as portas fechadas.")
                    except Exception as e:
                        print(f"[ERRO SQL] Falha ao fechar todas as portas: {e}")
                        
            else:
                # O som normalizou!
                if portas_fechadas:
                    try:
                        # Verifica se a simulação já terminou (Estado = '2')
                        db_cursor.execute("SELECT Estado FROM simulacao WHERE IDSimulacao = %s", (id_simulacao_atual,))
                        res_estado = db_cursor.fetchone()
                        
                        if res_estado and res_estado[0] == '2':
                            print("[ATUADOR SOM] Simulação já terminou! As portas vão permanecer seladas.")
                            portas_fechadas = False 
                        else:
                            db_cursor.execute("UPDATE corredor SET Aberto = 1 WHERE IDSimulacao = %s", (id_simulacao_atual,))
                            db_conn.commit()
                            portas_fechadas = False
                            historico_corredores.clear()
                            
                            msg = f"{{Type: OpenAllDoor, Player: {N_JOGADOR}}}"
                            client.publish(TOPIC_ACTUATORS, msg, qos=1)
                            print(f"[ATUADOR SOM] Nível normalizou ({valor}dB). Todas as portas reabertas.")
                            
                    except Exception as e:
                        print(f"[ERRO SQL] Falha ao reabrir portas: {e}")
                        
def verificar_gatilho_marsamis(client, sala, id_simulacao, cursor):
    try:
        cursor.execute("SELECT NumeroMarsamisOdd, NumeroMarsamisEven FROM ocupacaolabirinto WHERE Sala = %s AND IDSimulacao = %s", (sala, id_simulacao))
        resultado = cursor.fetchone()
        
        if resultado:
            odd, even = resultado
            if odd == even and odd > 0:
                msg = f"{{Type: Score, Player: {N_JOGADOR}, Room: {sala}}}"
                client.publish(TOPIC_ACTUATORS, msg, qos=1)
                print(f"[GATILHO SCORE] Sala {sala} - Igualdade confirmada pela BD (Odd:{odd}, Even:{even}). Comando: {msg}")
    except Exception as e:
        print(f"[ERRO GATILHO] Falha ao verificar sala {sala}: {e}")
            
def carregar_limites_nuvem():
    global limites_termino
    while True:
        try:
            print("[NUVEM] A carregar limites de término do labirinto (194.210.86.10)...")
            nuvem_conn = mysql.connector.connect(
                host=os.getenv('DB_CLOUD_HOST', '194.210.86.10'),
                user=os.getenv('DB_CLOUD_USER'),
                password=os.getenv('DB_CLOUD_PASS'),
                database=os.getenv('DB_CLOUD_NAME', 'maze'),
                connect_timeout=5
            )
            cursor = nuvem_conn.cursor(dictionary=True)
            cursor.execute("SELECT normaltemperature, temperaturevarhightoleration, temperaturevarlowtoleration, normalnoise, noisevartoleration FROM setupmaze LIMIT 1")
            resultado = cursor.fetchone()

            if resultado:
                t_normal = float(resultado['normaltemperature'])
                s_normal = float(resultado['normalnoise'])
                limites_termino['temp_max'] = t_normal + float(resultado['temperaturevarhightoleration'])
                limites_termino['temp_min'] = t_normal - float(resultado['temperaturevarlowtoleration'])
                limites_termino['som_max'] = s_normal + float(resultado['noisevartoleration'])

                print(f"[NUVEM] Limites de FIM DE JOGO obtidos: Temp({limites_termino['temp_min']} a {limites_termino['temp_max']}), Som(Max {limites_termino['som_max']})")

                cursor.close()
                nuvem_conn.close()
                break # deixa o script continuar
            else:
                print("[NUVEM] Dados incompletos na base de dados remota.")

        except Exception as e:
            print(f"[ERRO NUVEM] Falha ao carregar limites: {e}. A tentar de novo em 5 segundos...")

        time.sleep(5)

def manter_conexao_viva():
    global db_conn, db_cursor
    if db_conn is None or not db_conn.is_connected():
        try:
            print("[DB LOCAL] A estabelecer ligação persistente com MySQL...")
            db_conn = mysql.connector.connect(**MYSQL_CONFIG)
            db_cursor = db_conn.cursor()
        except mysql.connector.Error as err:
            print(f"[ERRO DB LOCAL] Não foi possível ligar: {err}")
            return False
    return True

def procurar_simulacao_ativa():
    global id_simulacao_atual, limites_alerta, jadeuprint
    global portas_fechadas, ocupacao_memoria, historico_corredores # Assegurar as globais
    
    if not manter_conexao_viva(): return
    try:
        db_conn.commit()
        db_cursor.execute("SELECT IDSimulacao, TempMaxAlerta, TempMinAlerta, RuidoMaxAlerta FROM simulacao WHERE Estado = '1' LIMIT 1")
        resultado = db_cursor.fetchone()

        if resultado:
            id_simulacao_atual = resultado[0]
            jadeuprint = False
            limites_alerta['temp_max'] = float(resultado[1]) if resultado[1] else None
            limites_alerta['temp_min'] = float(resultado[2]) if resultado[2] else None
            limites_alerta['som_max'] = float(resultado[3]) if resultado[3] else None
            print(f"[INIT LOCAL] Simulação ativa: ID {id_simulacao_atual}. Limites de ALERTA carregados.")
            db_cursor.execute("SELECT COUNT(*) FROM corredor WHERE Aberto = 0 AND IDSimulacao = %s", (id_simulacao_atual,))
            res_portas = db_cursor.fetchone()
            if res_portas and res_portas[0] > 0:
                portas_fechadas = True
                print("[BULLETPROOF] Recuperado: Existem portas fechadas nesta simulação.")
            else:
                portas_fechadas = False
            db_cursor.execute("""
                SELECT SalaOrigem, SalaDestino 
                FROM medicoespassagens 
                WHERE IDSimulacao = %s AND SalaOrigem != 0 AND SalaDestino != 0 
                ORDER BY IDMedicao DESC LIMIT 30
            """, (id_simulacao_atual,))
            res_movimentos = db_cursor.fetchall()
            historico_corredores.clear()
            for row in res_movimentos:
                origem, destino = row[0], row[1]
                corredor = (origem, destino)
                historico_corredores[corredor] = historico_corredores.get(corredor, 0) + 1
            print(f"[BULLETPROOF] Recuperado: Histórico de tráfego reconstruído a partir dos últimos {len(res_movimentos)} movimentos.")
            periodicidade_bd = resultado[4]
            if periodicidade_bd is not None:
                config_payload = {"Periodicidade": periodicidade_bd}
                mqtt_client.publish(TOPIC_CONFIG, json.dumps(config_payload), qos=2)
                print(f"[CONFIG] Periodicidade ({periodicidade_bd}s) enviada para o PC1!")
        else:
            print("[AVISO] Nenhuma simulação ativa (Estado=1) encontrada na BD.")
            id_simulacao_atual = None
    except Exception as e:
        print(f"[ERRO] Falha ao procurar simulação e reconstruir dados: {e}")

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] PC2 Ligado (Código: {rc})")
    client.subscribe([(TOPIC_MOV, 2), (TOPIC_TEMP, 0), (TOPIC_SOM, 0), (TOPIC_PING, 2)])

    if id_simulacao_atual is not None and manter_conexao_viva():
        try:
            db_cursor.execute("SELECT IDMongo FROM medicoespassagens WHERE IDSimulacao = %s ORDER BY IDMedicao DESC LIMIT 1", (id_simulacao_atual,))
            resultado = db_cursor.fetchone()
            ultimo_id = resultado[0] if resultado else None
            resend_payload = {"Player": N_JOGADOR, "last_id": ultimo_id}
            client.publish(TOPIC_RESEND, json.dumps(resend_payload), qos=2)
            print(f"[RESEND] Comando de sincronização pós-boot enviado ao PC1 (Último ID: {ultimo_id})")
        except Exception as e:
            print(f"[AVISO BOOT] Não foi possível verificar o último ID no MySQL no arranque: {e}")

def on_message(client, userdata, msg):
    global last_inserted_id, id_simulacao_atual, motivo, jadeuprint

    if not manter_conexao_viva(): return
    if id_simulacao_atual is None:
        procurar_simulacao_ativa()
        if id_simulacao_atual is None: return

    try:
        payload = json.loads(msg.payload.decode('utf-8'))

        if msg.topic == TOPIC_MOV:
            sucesso_bloco = True
            salas_para_verificar = set() 
            
            for mov in payload:
                is_recente = mensagem_recente(mov.get('Hour'))
                
                marsami_id = int(mov['Marsami'])
                origem = mov['RoomOrigin']
                destino = mov['RoomDestiny']

                if destino != 0 and origem != 0:
                    corredor = (origem, destino)
                    historico_corredores[corredor] = historico_corredores.get(corredor, 0) + 1
                    
                try:
                    db_cursor.callproc('SP_RegistarPassagem', [
                        id_simulacao_atual, mov['Marsami'], mov['RoomOrigin'],
                        mov['RoomDestiny'], mov['Status'], mov['_id']
                    ])
                    last_inserted_id = mov['_id']
                    if destino != 0 and is_recente: 
                        salas_para_verificar.add(destino)
                except mysql.connector.Error as err:
                    print(f"[SQL] Erro no movimento {mov['_id']}: {err}")
                    sucesso_bloco = False
                    break 

            if sucesso_bloco:
                db_conn.commit() 
                ack_payload = {"Player": N_JOGADOR, "last_id": last_inserted_id, "status": "OK"}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
                
                # Disparar gatilhos APENAS para os dados recentes e consultando a BD!
                for sala in salas_para_verificar:
                    verificar_gatilho_marsamis(client, sala, id_simulacao_atual, db_cursor)
            else:
                # O PC2 avisa o PC1 IMEDIATAMENTE que o MySQL falhou!
                ack_payload = {"Player": N_JOGADOR, "status": "ERROR_DB"}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
                print("[SQL] Aviso de ERROR_DB enviado instantaneamente ao PC1!")

        elif msg.topic == TOPIC_PING:
            try:
                db_cursor.execute("SELECT IDMongo FROM medicoespassagens WHERE IDSimulacao = %s ORDER BY IDMedicao DESC LIMIT 1", (id_simulacao_atual,))
                resultado = db_cursor.fetchone()
                ultimo_id_bd = resultado[0] if resultado else None
                ack_payload = {"Player": N_JOGADOR, "last_id": ultimo_id_bd, "status": "OK"}
                client.publish(TOPIC_ACK, json.dumps(ack_payload), qos=2)
                print(f"[SYNC] O PC1 pediu estado atual. Respondido com last_id: {ultimo_id_bd}")
            except mysql.connector.Error as err:
                print(f"[ERRO SYNC] PC1 pediu estado, mas o MySQL está em baixo: {err}")
                err_payload = {"Player": N_JOGADOR, "status": "ERROR_DB"}
                client.publish(TOPIC_ACK, json.dumps(err_payload), qos=2)

        elif msg.topic in [TOPIC_TEMP, TOPIC_SOM]:
            val = float(payload.get('Temperature') or payload.get('Sound'))
            hora_sensor = payload.get('Hour')
            sensor_type = 'T' if 'Temperature' in payload else 'S'
            is_alerta = False
            is_terminar= False
            tipo_alerta = ""
            texto_mensagem = ""

            if sensor_type == 'T':
                db_cursor.execute("INSERT INTO temperatura (Hora, Temperatura) VALUES (%s, %s)", (hora_sensor, val))
                if limites_alerta['temp_max'] is not None and val > limites_alerta['temp_max']:
                    is_alerta = True
                    tipo_alerta = "Temperatura Máxima"
                    texto_mensagem = f"Atenção! A temperatura atingiu {val}ºC."
                elif limites_alerta['temp_min'] is not None and val < limites_alerta['temp_min']:
                    is_alerta = True
                    tipo_alerta = "Temperatura Mínima"
                    texto_mensagem = f"Atenção! A temperatura desceu para {val}ºC."
                if limites_termino['temp_max'] is not None and val > limites_termino['temp_max']:
                    motivo="Temperatura max atingida"
                    is_terminar=True
                elif limites_termino['temp_min'] is not None and val < limites_termino['temp_min']:
                    motivo="Temperatura min atingida"
                    is_terminar=True
                
            else:
                db_cursor.execute("INSERT INTO som (Hora, Som) VALUES (%s, %s)", (hora_sensor, val))
                if limites_alerta['som_max'] is not None and val > limites_alerta['som_max']:
                    is_alerta = True
                    tipo_alerta = "Ruído Máximo"
                    texto_mensagem = f"Atenção! O nível de ruído atingiu {val}dB."
                if limites_termino['som_max'] is not None and val > limites_termino['som_max']:
                    motivo="Som max atingido"
                    is_terminar=True
                    
            if is_alerta:
                db_cursor.callproc('SP_RegistarAlerta', [id_simulacao_atual, sensor_type, val, tipo_alerta, texto_mensagem, hora_sensor])

            if is_terminar:
                db_cursor.execute("UPDATE simulacao SET motivo_fim = IFNULL(motivo_fim, %s) WHERE IDSimulacao = %s", (motivo, id_simulacao_atual))
                if not jadeuprint:

                    print(f"[FIM SIMULAÇÃO] Motivo: {motivo} Valor: {val}.")
                    jadeuprint=True


            db_conn.commit()
            
            # Aplicação do Filtro Temporal: Se vieram 300 logs de som após quebra, 
            # não vai disparar atuadores com 1 hora de atraso
            is_recente = mensagem_recente(hora_sensor)
            if is_recente:
                verificar_sensores_atuadores(client, sensor_type, val) 

    except Exception as e:
        print(f"[ERRO CRÍTICO] {e}")

mqtt_client = mqtt.Client(client_id="Grupo7_PC2_Monitor")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
broker_address = args.broker.split(':')[0]
broker_port = int(args.broker.split(':')[1]) if ':' in args.broker else 1883

carregar_limites_nuvem()
procurar_simulacao_ativa()

print("--- PC2: Monitor de Migração Ativo (Versão Final com Nuvem e BD Local) ---")
mqtt_client.connect(broker_address, broker_port, 60)
mqtt_client.loop_forever()