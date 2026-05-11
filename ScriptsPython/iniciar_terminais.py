import os
import sys
import platform
import subprocess

# fazer: pip install paho-mqtt pymongo mysql-connector-python python-dotenv

def abrir_novo_terminal(caminho_script):
    """Abre um script Python numa nova janela de terminal, dependendo do Sistema Operativo."""
    os_name = platform.system()
    python_exe = sys.executable  # Usa o Python da tua .venv automaticamente!

    if os_name == "Windows":
        # No Windows, usamos a flag para criar uma consola nova independente
        subprocess.Popen([python_exe, caminho_script], creationflags=subprocess.CREATE_NEW_CONSOLE)

    elif os_name == "Darwin":  # macOS
        # ATUALIZADO: Usamos plicas (') para envolver os caminhos, é mais seguro no bash/zsh do Mac
        comando_shell = f"'{python_exe}' '{caminho_script}'"
        script_mac = f'''
        tell application "Terminal"
            activate
            do script "{comando_shell}"
        end tell
        '''
        # run em vez de Popen para garantir que o AppleScript é executado corretamente
        subprocess.run(["osascript", "-e", script_mac])

    else:
        # Linux
        subprocess.Popen(["gnome-terminal", "--", python_exe, caminho_script])


def main():
    # 1. Descobrir dinamicamente onde este ficheiro (launcher) está guardado
    pasta_atual = os.path.dirname(os.path.abspath(__file__))

    # 2. Construir os caminhos exatos para os scripts
    path_to_mongo = os.path.join(pasta_atual, "Mongo(PC1)", "to_mongo.py")
    path_mongo_mqtt = os.path.join(pasta_atual, "Mongo(PC1)", "MongoToMQTT.py")
    path_mqtt_mysql = os.path.join(pasta_atual, "MySQL(PC2)", "MQTTToMySQL.py")

    # 3. Menu na consola
    print("===========================================")
    print("      LAUNCHER DE SCRIPTS - PISID 2026     ")
    print("===========================================")
    print("1 - Iniciar Scripts PC1 (to_mongo + MongoToMQTT)")
    print("2 - Iniciar Script PC2 (MQTTToMySQL)")
    print("===========================================")

    escolha = input("Escolha uma opção (1 ou 2): ")

    # 4. Lógica de execução
    if escolha == '1':
        print("\nA abrir o 'to_mongo.py' e o 'MongoToMQTT.py' em terminais separados...")
        abrir_novo_terminal(path_to_mongo)
        abrir_novo_terminal(path_mongo_mqtt)
        print("Feito! Podes fechar esta janela do PyCharm se quiseres.")

    elif escolha == '2':
        print("\nA abrir o 'MQTTToMySQL.py' num novo terminal...")
        abrir_novo_terminal(path_mqtt_mysql)
        print("Feito! Podes fechar esta janela do PyCharm se quiseres.")

    else:
        print("\nErro: Opção inválida. Corre o script novamente.")


if __name__ == "__main__":
    main()