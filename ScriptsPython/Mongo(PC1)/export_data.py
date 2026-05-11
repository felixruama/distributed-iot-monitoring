import pymongo
import csv
import sys

from datetime import datetime

MONGO_URI = "mongodb://localhost:27017/?directConnection=true"
DB_NAME = "sensores_db"
COLECOES = ["Som", "Temperatura", "Movimento"]


def buscar_anomalias_no_mongo(id_simulacao=None):
    client = pymongo.MongoClient(MONGO_URI)
    db = client[DB_NAME]
    lista_anomalias = []

    for nome_col in COLECOES:
        col = db[nome_col]
        query = {"Anomalia": True}
        if id_simulacao:
            query["IDSimulacao"] = int(id_simulacao)

        cursor = col.find(query)
        for doc in cursor:
            doc["Fonte_Sensor"] = nome_col  # metadados para o técnico se localizar
            lista_anomalias.append(doc)

    client.close()
    return lista_anomalias


def gerar_csv(dados, id_simulacao="geral"):
    agora = datetime.now()
    timestamp_log = agora.strftime('%Y-%m-%d %H:%M:%S')
    filename = f"auditoria_sim_ {id_simulacao}_{agora.strftime('%Y%m%d_%H%M')}.csv"
    # Sem dados
    if not dados:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(f"RELATORIO DE AUDITORIA - MAZERUN 2026\n")
            f.write(f"Gerado em: {timestamp_log}\n")
            f.write("-" * 40 + "\n")
            f.write("STATUS: Nenhuma anomalia encontrada no periodo selecionado.\n")
        print(f"[!] Relatorio gerado (vazio): {filename}")
        return

    # Com dados
    headers = set()
    for item in dados:
        headers.update(item.keys())

    try:
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            # Fieldnames ordenados para consistencia
            writer = csv.DictWriter(f, fieldnames=sorted(list(headers)))
            writer.writeheader()
            writer.writerows(dados)
        print(f"[+] RELATORIO GERADO: {filename} ({len(dados)} registos)")
    except Exception as e:
        print(f"[!] Erro ao gravar ficheiro: {e}")

if __name__ == "__main__":
    # Tenta apanhar o ID enviado pelo PHP
    id_arg = sys.argv[1] if len(sys.argv) > 1 else None
    # 1. Busca específica ou geral
    dados_anomalos = buscar_anomalias_no_mongo(id_arg)
    # 2. Exportação
    gerar_csv(dados_anomalos, id_arg if id_arg else "Geral")
