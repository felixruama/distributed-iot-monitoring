import os
import sys
import platform
import subprocess
import argparse


def abrir_novo_terminal(caminho_script, argumentos_extra=None):
    """Abre um script Python numa nova janela de terminal, passando os argumentos opcionais."""
    if argumentos_extra is None:
        argumentos_extra = []

    os_name = platform.system()
    python_exe = sys.executable

    if os_name == "Windows":
        comando = [python_exe, caminho_script] + argumentos_extra
        subprocess.Popen(comando, creationflags=subprocess.CREATE_NEW_CONSOLE)

    elif os_name == "Darwin":  # macOS
        str_args = " ".join([f"'{arg}'" for arg in argumentos_extra])
        comando_shell = f"'{python_exe}' '{caminho_script}' {str_args}"

        script_mac = f'''
        tell application "Terminal"
            activate
            do script "{comando_shell}"
        end tell
        '''
        subprocess.run(["osascript", "-e", script_mac])

    else:
        # Linux (Ubuntu/Debian com gnome-terminal)
        comando = ["gnome-terminal", "--", python_exe, caminho_script] + argumentos_extra
        subprocess.Popen(comando)


def main():
    # 1. Preparar o Argparse para ler as opções diretamente do terminal
    parser = argparse.ArgumentParser(description="LAUNCHER DE SCRIPTS - PISID 2026")
    parser.add_argument('--op', type=str, choices=['1', '2'], help="Opção a executar (1: PC1, 2: PC2)")
    parser.add_argument('--broker', type=str, default="broker.hivemq.com:1883",
                        help="Endereço do Broker MQTT (ex: host:porta)")
    parser.add_argument('--mongo', type=str, default="mongodb://localhost:27017/?directConnection=true",
                        help="URI do MongoDB")
    args = parser.parse_args()

    # 2. Descobrir dinamicamente onde este ficheiro está guardado
    pasta_atual = os.path.dirname(os.path.abspath(__file__))

    # 3. Definir os caminhos para os sub-scripts
    path_to_mongo = os.path.join(pasta_atual, "Mongo(PC1)", "to_mongo.py")
    path_mongo_mqtt = os.path.join(pasta_atual, "Mongo(PC1)", "MongoToMQTT.py")
    path_mqtt_mysql = os.path.join(pasta_atual, "MySQL(PC2)", "MQTTToMySQL.py")
    path_vigilante = os.path.join(pasta_atual, "vigilante_windows.py")

    # Se o utilizador não passou o "--op", mostra o menu interativo
    escolha = args.op
    if not escolha:
        print("===========================================")
        print("      LAUNCHER DE SCRIPTS - PISID 2026     ")
        print(f" Broker padrão: {args.broker}")
        print(f" Mongo padrão:  {args.mongo}")
        print("===========================================")
        print("1 - Iniciar Scripts PC1 (to_mongo + MongoToMQTT)")
        print("2 - Iniciar Script PC2 (MQTTToMySQL + Vigilante)")
        print("===========================================")
        escolha = input("Escolha uma opção (1 ou 2): ")

    # 4. Lógica de execução conforme a escolha
    if escolha == '1':
        print("\nA abrir os terminais do PC1 com as configurações passadas...")
        # O PC1 precisa das variáveis de Broker e Mongo
        args_pc1 = ['--broker', args.broker, '--mongo', args.mongo]
        abrir_novo_terminal(path_to_mongo, args_pc1)
        abrir_novo_terminal(path_mongo_mqtt, args_pc1)
        print("Feito!")

    elif escolha == '2':
        print("\nA abrir os terminais do PC2 (Migrador + Vigilante) com as configurações passadas...")
        # O PC2 só precisa da variável do Broker
        args_pc2 = ['--broker', args.broker]
        abrir_novo_terminal(path_mqtt_mysql, args_pc2)
        abrir_novo_terminal(path_vigilante, args_pc2)
        print("Feito!")

    else:
        print("\nErro: Opção inválida.")


if __name__ == "__main__":
    main()