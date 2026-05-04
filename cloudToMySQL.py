import sys
import mysql.connector
import json
from mysql.connector import Error

#Configuracoes
N_JOGADOR = 7
MYSQL_CONFIG = {
    'user': 'root',
    'password': 'root',
    'host': 'localhost',
    'database': 'labirinto_db_final'
}

CONFIG_NUVEM = {
    'host': '194.210.86.10',
    'user': 'aluno',
    'password': 'aluno',
    'database': 'maze'
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

        #total de marsamis
        cursor.execute("SELECT numbermarsamis FROM SetupMaze LIMIT 1")
        setup = cursor.fetchone()

        # corredores
        cursor.execute("SELECT RoomA, RoomB FROM Corridor")
        corredores = cursor.fetchall()

        return setup, corredores
    except Error as e:
        print(f"[ERRO NUVEM] {e}")
        return None, None
    finally:
        if 'conn' in locals() and conn.is_connected():
            conn.close()


def preparar_simulacao(id_utilizador):
    setup_info, lista_corredores = obter_dados_nuvem()
    if not setup_info or not lista_corredores:
        return

    db = obter_db()
    if not db: return

    try:
        cursor = db.cursor()
        cursor.callproc('SP_CriarSimulacao', [id_utilizador, ""])

        cursor.execute("SELECT MAX(IDSimulacao) FROM simulacao")
        res = cursor.fetchone()
        id_simulacao = res[0]

        if id_simulacao is None:
            print("[ERRO] Falha ao recuperar o ID da simulação.")
            return

        print(f"[SETUP] A configurar Simulação ID: {id_simulacao} para o Utilizador: {id_utilizador}")

        #Inserir Corredores
        for c in lista_corredores:
            sql_corr = "INSERT INTO corredor (Aberto, IDSalaA, IDSalaB, IDSimulacao) VALUES (%s, %s, %s, %s)"
            cursor.execute(sql_corr, (1, c['RoomA'], c['RoomB'], id_simulacao))

        # PASSO D: Inserir Marsamis
        n_marsamis = int(setup_info['numbermarsamis'])
        for i in range(1, n_marsamis + 1):
            sql_mar = "INSERT INTO marsami (IDMarsami, Cansado, IDSala, IDSimulacao) VALUES (%s, %s, %s, %s)"
            cursor.execute(sql_mar, (i, 0, 1, id_simulacao))  #ou sala a null

        db.commit()
        print(f"[SUCESSO] Infraestrutura pronta: {len(lista_corredores)} corredores e {n_marsamis} marsamis.")
        cursor.close()

    except Exception as e:
        print(f"[ERRO CRÍTICO] {e}")
        db.rollback()

if __name__ == "__main__":
    #ID do utilizador passado pelo PHP
    if len(sys.argv) > 1:
        id_u = sys.argv[1]
    else:
        # default para testes manuais
        id_u = 1
        print("[AVISO] Nenhum IDUtilizador fornecido. A usar ID=1.")

    preparar_simulacao(id_u)