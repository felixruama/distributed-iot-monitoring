import os
import time
import json
import threading
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
import paho.mqtt.client as mqtt
import mysql.connector

load_dotenv() #Vai ler as passwords e IPs escondidos no ficheiro .env (segurança)

# Configurações Iniciais
N_JOGADOR = 7
MONGO_URI = os.getenv("MONGO_URI", "mongodb://root:root@localhost:27017/")
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
def on_connect(client, userdata, flags, rc): #client-> é scrpt(S1),userdata e falgs_> é usado pela biblioteca(não importante),rc-> código que o servidor envia 0=sucesso outro número falha na ligação por motivo x
    print(f"[MQTT] S1 Ligado ao Broker (Código: {rc})")
    client.subscribe(TOPIC_ACK, qos=2) # subscribe no tópico pisid_response_7
    client.subscribe(TOPIC_CONFIG, qos=2) #subscribe no tópico pisid_config_7

def on_message_back(client, userdata, msg): #nossa thread backgroud
    global periodicidade, last_ack_id# dá autorização ao MQTT para mudar a periodicidade e o id do último ack
    try:
        payload = json.loads(msg.payload.decode('utf-8')) #decode transforma a mensagem de bytes para texto, json.load -->deixa mais facil para lermos

        if msg.topic == TOPIC_ACK: #essas mensagens tem o número do player,last_id e status--> 0 (erro) e 1 (sucesso)
            last_ack_id = payload.get("last_id")#atuliza o last_ack_id
            ack_event.set() #verde
            print(f"[ACK] Recebido do PC2. Último ID inserido: {last_ack_id}")

        elif msg.topic == TOPIC_CONFIG:#nessa mensagem só vem a periodicidade
            nova_periodicidade = payload.get("Periodicidade")
            if nova_periodicidade:
                periodicidade = float(nova_periodicidade)
                print(f"[CONFIG] Periodicidade atualizada remotamente para: {periodicidade}s")
    except Exception as e:
        print(f"[MQTT] Erro no processamento da mensagem: {e}")


# Configurar Cliente MQTT
mqtt_client = mqtt.Client(client_id=f"Grupo7_PC1_v3") #comos nos chamamos na rede (não pode ter dois nomes iguais)
mqtt_client.on_connect = on_connect#conecta
mqtt_client.on_message = on_message_back#fica a escutar
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60) # a cada 60 seguindo anda um ping para avisar que estou cá msm estando caaldo
mqtt_client.loop_start()#cria uma via paralela, fica a escutar em uma thread backgroud mas ainda executa o main principal

db = MongoClient(MONGO_URI)[MONGO_DB]# Ligar ao MongoDB

# Listas para guardar as últimas 5 medições
historico_som = []
historico_temp = []

def calcular_media(lista):
    if not lista: return 0
    return sum(lista) / len(lista)

def processar_som_temperatura_sec(): #nossa thread secundária
    while True:
        try:
            filtro_crus = {
                "Migrado": False,
                "isOutlier": False,
                "Anomalia": False
            } # Pede ao Mongo APENAS o que ainda não foi migrado ou se já foi visto que é outlier/anomalia

            for col_name, topic in [("Som", TOPIC_SOM), ("Temperatura", TOPIC_TEMP)]:
                docs = list(db[col_name].find(filtro_crus).limit(50))#garantem que o Python só lê blocos de 50 leituras de cada vez.

                for doc in docs:
                    doc_id = doc["_id"]
                    valor = doc.get("Sound") if col_name == "Som" else doc.get("Temperature")
                    hora = doc.get("Hour")

                    e_anomalia = False
                    e_outlier = False

                    #TRATA ANOMALIAS
                    try:
                        hora_limpa = str(hora).replace('T', ' ')[:19]
                        datetime.strptime(hora_limpa, "%Y-%m-%d %H:%M:%S")
                    except ValueError:
                        e_anomalia = True
                        print(f"[ANOMALIA DATA] Lixo detetado em {col_name}: Data impossível ('{hora}')!")

                    try:
                        valor = float(valor) # Tenta forçar o valor a ser um número decimal
                        #valores impossíveis:
                        if col_name == "Som" and valor < 0:
                            e_anomalia = True
                            print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é fisicamente possível!")
                        elif col_name == "Temperatura" and (valor < -50 or valor > 150):
                            e_anomalia = True
                            print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é fisicamente possível!")

                    except (ValueError, TypeError): #caso seja letra ou simbolo aka não numerico
                        e_anomalia = True
                        print(f"[ANOMALIA TIPO] Lixo detetado em {col_name}: O valor '{valor}' não é numérico!")

                    # TRATAR OUTLIERS ( média das últimas 5 medições)
                    if not e_anomalia:
                        lista_historico = historico_som if col_name == "Som" else historico_temp

                        # Escolhe a constante certa consoante o sensor
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

                    # REGISTO E ENVIO (Igual ao anterior)
                    if e_anomalia:
                        db[col_name].update_one(
                            {"_id": doc_id},
                            {"$set": {"Anomalia": True}}
                        )
                        continue # Interrompe aqui para este 'doc' e passa ao próximo

                    if e_outlier:
                        db[col_name].update_one(
                            {"_id": doc_id},
                            {"$set": {"isOutlier": True}}
                        )
                        continue

                    payload = {**doc, "_id": str(doc_id)}
                    mqtt_client.publish(topic, json.dumps(payload), qos=0)

                    db[col_name].update_one(
                        {"_id": doc_id},
                        {"$set": {"Migrado": True}}
                    )

        except Exception as e:
            print(f"[THREAD 2] Erro: {e}")

        time.sleep(periodicidade)

# --- MAIN THREAD: Movimentos em Blocos com Handshake (QoS 2) ---
def processar_movimentos_main(): #nosso ciclo main
    global last_ack_id
    print("--- Início da Migração de Movimentos por Blocos com Handshake ---")

    while True:
        try:
            # 1. Obter bloco de movimentos não migrados
            filtro_mov = {"Migrado": False, "Anomalia": False}
            batch = list(db.Movimento.find(filtro_mov).sort("Hour", 1).limit(BATCH_SIZE))

            if not batch:
                time.sleep(periodicidade)
                continue

            # --- ALTERAÇÃO AQUI: Implementação da Validação de Movimentos ---
            batch_data = []
            for doc in batch:
                try:
                    marsami_id = int(doc["Marsami"])
                    origem = int(doc["RoomOrigin"])
                    destino = int(doc["RoomDestiny"])

                    # Regra 1: Marsami tem de existir
                    if not (1 <= marsami_id <= max_marsamis_global):
                        raise ValueError(f"Marsami ID {marsami_id} é inválido/não existe.")

                    # Regra 2: O corredor tem de existir (origem 0 é exceção pois é o limbo/arranque)
                    if origem != 0:
                        corredor_valido = any(c['Rooma'] == origem and c['Roomb'] == destino for c in lista_corredores_global)
                        if not corredor_valido:
                            raise ValueError(f"O corredor {origem}->{destino} não existe no labirinto!")

                    batch_data.append({**doc, "_id": str(doc["_id"])})

                except Exception as err:
                    print(f"[ANOMALIA MOVIMENTO] Detetado lixo: {err}")
                    # Assinala como anomalia para não bloquear a fila, mas fica no Mongo para histórico
                    db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Anomalia": True, "Migrado": True}})

            # Se todos os documentos do batch eram lixo, saltar para a próxima iteração
            if not batch_data:
                continue

            ids_no_bloco = [d["_id"] for d in batch_data]
            sucesso_bloco = False

            while not sucesso_bloco:
                print(f"[MAIN] Enviando bloco de {len(batch_data)} movimentos válidos...")
                ack_event.clear()
                mqtt_client.publish(TOPIC_MOV, json.dumps(batch_data), qos=2)

                # 3. Esperar ACK normal (5 segundos)
                recebeu_resposta = ack_event.wait(timeout=5.0)

                # 4. Se falhou, Handshake "didyougetit"
                if not recebeu_resposta:
                    print(f"[MAIN] Timeout! Perguntando ao PC2: Did you get it?")
                    ack_event.clear()
                    ping_payload = {"Player": N_JOGADOR}
                    mqtt_client.publish(TOPIC_PING, json.dumps(ping_payload), qos=2)

                    # Espera pela resposta ao Ping (3 segundos)
                    recebeu_resposta = ack_event.wait(timeout=3.0)

                # 5. Avaliar o resultado (veio do ACK normal OU do Ping)
                if recebeu_resposta:
                    # Se o ID reportado pelo PC2 estiver no nosso bloco atual
                    if last_ack_id in ids_no_bloco:
                        # Marcar como migrados no Mongo ATÉ ao ID confirmado
                        for doc in batch_data: # Corrigido para iterar sobre os válidos
                            db.Movimento.update_one({"_id": doc["_id"]}, {"$set": {"Migrado": True}})
                            if str(doc["_id"]) == last_ack_id:
                                break # Para de marcar, os seguintes (se houver) falharam e vão no prox bloco

                        print(f"[MAIN] Bloco confirmado até {last_ack_id}.")
                        sucesso_bloco = True # nao quer dizer que registou todas as mensagens do bloco, as que nao foram registadas serao enviadas no proximo bloco
                    else:
                        # O ID reportado é antigo ou None (o PC2 não conseguiu inserir nada deste bloco)
                        print(f"[MAIN] ID ({last_ack_id}) é antigo. O bloco atual falhou a inserção. Reenviando...")
                else:
                    # Falhou tudo, PC2 incontactável ou broker muito lento
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
            password="aluno", #FALTA METER ISTO NO ENV
            database="maze"
        )
        cursor = conexao_nuvem.cursor(dictionary=True)

        # Vai buscar a configuração base do labirinto
        cursor.execute("SELECT normaltemperature, normalnoise, numbermarsamis FROM setupmaze LIMIT 1")
        resultado = cursor.fetchone()

        # --- ALTERAÇÃO AQUI: Vai buscar as salas válidas para a validação de movimentos ---
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
    # Iniciar thread secundária para Som e Temp
    t = threading.Thread(target=processar_som_temperatura_sec, daemon=True)
    t.start()

    # Executar lógica de movimentos no Main
    processar_movimentos_main()