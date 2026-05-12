import os
import time
import subprocess
import mysql.connector
import argparse
import sys

# ==========================================
# 1. LER ARGUMENTOS OPCIONAIS DA CONSOLA
# ==========================================
parser = argparse.ArgumentParser(description="Script: Vigilante do Windows")
parser.add_argument('--broker', type=str, default="broker.hivemq.com:1883", help="Endereço do Broker MQTT (host:porta)")
args = parser.parse_args()

broker_address = args.broker.split(':')[0]
broker_port = args.broker.split(':')[1] if ':' in args.broker else "1883"

# ==========================================
# 2. CONFIGURAR A LIGAÇÃO À BASE DE DADOS
# ==========================================
DB_CONFIG = {
    'host': 'localhost',  # Corre no teu computador, logo é localhost
    'user': 'root',
    'password': 'root',   # Confirma se é esta a tua password
    'database': 'labirinto_DB'
}

def main():
    pasta_atual = os.path.dirname(os.path.abspath(__file__))
    script_cloud = os.path.join(pasta_atual, "MySQL(PC2)", "cloudToMySQL.py")
    path_mazerun = os.path.abspath(os.path.join(pasta_atual, "..", "Mazerun", "mazerun.exe"))

    ultimo_id_iniciado = None

    print("=====================================================")
    print(" 👀 VIGILANTE DO WINDOWS ATIVADO - À ESPERA DO SITE... ")
    print(f" -> Broker Alvo: {broker_address} (Porta: {broker_port})")
    print("=====================================================")

    while True:
        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            cursor = conn.cursor(dictionary=True)

            # Procura simulações no estado '1'
            cursor.execute("SELECT IDSimulacao FROM simulacao WHERE Estado = '1' ORDER BY IDSimulacao DESC LIMIT 1")
            resultado = cursor.fetchone()

            if resultado:
                id_atual = resultado['IDSimulacao']

                if id_atual != ultimo_id_iniciado:
                    print(f"\n[!] NOVA SIMULAÇÃO DETETADA NO SITE! (ID: {id_atual})")
                    ultimo_id_iniciado = id_atual

                    # PASSO 1: Correr a extração da Nuvem e passar o ID da simulação
                    print("-> A executar a sincronização cloudToMySQL.py...")
                    # O sys.executable garante que usa o mesmo Python/ambiente virtual
                    subprocess.run([sys.executable, script_cloud, str(id_atual)])
                    print("-> Sincronização concluída!")

                    # PASSO 2: Abrir o Mazerun com as variáveis dinâmicas
                    print("-> A abrir o jogo Mazerun no ecrã...")
                    argumentos = [
                        path_mazerun, "7",
                        "--broker", broker_address,
                        "--portbroker", str(broker_port),
                        "--flagMessage", "1"
                    ]
                    subprocess.Popen(argumentos)

            cursor.close()
            conn.close()

        except mysql.connector.Error as err:
            print(f"Erro ao ligar à BD: {err}")
        except Exception as e:
            print(f"Ocorreu um erro: {e}")

        # Aguarda 3 segundos antes de verificar novamente
        time.sleep(3)

if __name__ == "__main__":
    main()