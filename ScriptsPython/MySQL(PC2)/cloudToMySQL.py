import sys
import mysql.connector
import json
from mysql.connector import Error
import os
from dotenv import load_dotenv

pasta_atual = os.path.dirname(os.path.abspath(__file__)) #pip install python-dotenv
load_dotenv(os.path.join(pasta_atual, "..", ".env"))

# Configuracoes MySQL Local
MYSQL_CONFIG = {
    'host': os.getenv('DB_LOCAL_HOST', 'localhost'),
    'user': os.getenv('DB_LOCAL_USER'),
    'password': os.getenv('DB_LOCAL_PASS'),
    'database': os.getenv('DB_LOCAL_NAME', 'labirinto_DB')
}

# Configuracoes MySQL Nuvem
CONFIG_NUVEM = {
    'host': os.getenv('DB_CLOUD_HOST', '194.210.86.10'),
    'user': os.getenv('DB_CLOUD_USER'),
    'password': os.getenv('DB_CLOUD_PASS'),
    'database': os.getenv('DB_CLOUD_NAME', 'maze')
}

db_conn = None

def obter_db():
    global db_conn
    if db_conn is None or not db_conn.is_connected():
        try:
            db_conn = mysql.connector.connect(**MYSQL_CONFIG)
            print("[DB LOCAL] Ligação persistente estabelecida.")
        except mysql.connector.Error as err:
            print(f"[ERRO DB LOCAL] Falha ao ligar: {err}")
            return None
    return db_conn

def obter_dados_nuvem():
    try:
        conn = mysql.connector.connect(**CONFIG_NUVEM)
        cursor = conn.cursor(dictionary=True)

        # total de marsamis
        cursor.execute("SELECT numbermarsamis FROM setupmaze LIMIT 1")
        setup = cursor.fetchone()

        # corredores
        cursor.execute("SELECT Rooma, Roomb FROM corridor")
        corredores = cursor.fetchall()

        return setup, corredores
    except Error as e:
        print(f"[ERRO NUVEM] {e}")
        return None, None
    finally:
        if 'conn' in locals() and conn.is_connected():
            conn.close()

def preparar_simulacao(id_simulacao_input=None):
    setup_info, lista_corredores = obter_dados_nuvem()
    if not setup_info or not lista_corredores:
        return

    db = obter_db()
    if not db: return

    try:
        cursor = db.cursor()

        # Determinar qual Simulação usar
        if id_simulacao_input is not None:
            id_simulacao = int(id_simulacao_input)
            # Verifica se existe E se está no estado 1
            cursor.execute("SELECT Estado FROM simulacao WHERE IDSimulacao = %s AND Estado = '1'", (id_simulacao,))
            if not cursor.fetchone():
                print(f"[ERRO] A Simulação ID {id_simulacao} não está ativa (Estado = '1') ou não existe.")
                return
        else:
            # Procura automaticamente a simulação que está Ativa (Estado '1')
            cursor.execute("SELECT IDSimulacao FROM simulacao WHERE Estado = '1' LIMIT 1")
            res = cursor.fetchone()

            if res is None or res[0] is None:
                print("[ERRO] Nenhuma simulação no estado 'A decorrer' (1) foi encontrada. Inicie a simulação primeiro.")
                return

            id_simulacao = res[0]

        print(f"[SETUP] A configurar Simulação ID: {id_simulacao}...")

        salas_unicas = set()

        # Inserir Corredores e extrair as salas únicas
        for c in lista_corredores:
            salas_unicas.add(c['Rooma'])
            salas_unicas.add(c['Roomb'])
            sql_corr = "INSERT INTO corredor (Aberto, IDSalaA, IDSalaB, IDSimulacao) VALUES (%s, %s, %s, %s)"
            cursor.execute(sql_corr, (1, c['Rooma'], c['Roomb'], id_simulacao))

        # Inserir Marsamis no Limbo (Sala 0)
        n_marsamis = int(setup_info['numbermarsamis'])
        for i in range(1, n_marsamis + 1):
            sql_mar = "INSERT INTO marsami (IDMarsami, Cansado, IDSala, IDSimulacao) VALUES (%s, %s, %s, %s)"
            cursor.execute(sql_mar, (i, 0, 0, id_simulacao))

        # Inserir linhas das salas na ocupacaolabirinto a zeros
        for sala in salas_unicas:
            sql_ocup = "INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao) VALUES (0, 0, %s, %s)"
            cursor.execute(sql_ocup, (sala, id_simulacao))

        db.commit()
        print(f"[SUCESSO] Infraestrutura pronta: {len(lista_corredores)} corredores, {len(salas_unicas)} salas criadas a 0, e {n_marsamis} marsamis no Limbo (Sala 0).")
        cursor.close()

    except Exception as e:
        print(f"[ERRO CRÍTICO] {e}")
        db.rollback()

if __name__ == "__main__":
    id_sim = None

    # Agora só aceita 1 parâmetro opcional: O ID da Simulação
    if len(sys.argv) > 1:
        id_sim = sys.argv[1]

    preparar_simulacao(id_sim)