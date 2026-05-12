import pymongo
import csv
import sys
from datetime import datetime
#python export_data.py <ID_simulação>

MONGO_URI = "mongodb://localhost:27017/?directConnection=true"
DB_NAME = "sensores_db"
COLECOES = ["Som", "Temperatura", "Movimento"]

def buscar_dados_no_mongo(tipo_filtro, id_simulacao=None):
    """
    tipo_filtro: 'Anomalia' ou 'Outlier'
    """
    client = pymongo.MongoClient(MONGO_URI)
    db = client[DB_NAME]
    lista_resultados = []

    for nome_col in COLECOES:
        col = db[nome_col]
        # Procura por Anomalia: True ou Outlier: True conforme o pedido
        query = {tipo_filtro: True}

        if id_simulacao:
            query["IDSimulacao"] = int(id_simulacao)

        cursor = col.find(query)
        for doc in cursor:
            doc["Fonte_Sensor"] = nome_col  # Metadados para o técnico
            doc["Tipo_Registo"] = tipo_filtro # Identificador extra no CSV
            lista_resultados.append(doc)

    client.close()
    return lista_resultados

def gerar_csv(dados, prefixo, id_simulacao="geral"):
    agora = datetime.now()
    timestamp_log = agora.strftime('%Y-%m-%d %H:%M:%S')
    # Nome do ficheiro agora inclui se é anomalia ou outlier
    filename = f"{prefixo.lower()}_sim_{id_simulacao}_{agora.strftime('%Y%m%d_%H%M')}.csv"

    if not dados:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(f"RELATORIO DE {prefixo.upper()} - MAZERUN 2026\n")
            f.write(f"Gerado em: {timestamp_log}\n")
            f.write("-" * 40 + "\n")
            f.write(f"STATUS: Nenhum(a) {prefixo} encontrado(a) no periodo.\n")
        print(f"[!] Ficheiro de {prefixo} gerado (vazio): {filename}")
        return

    headers = set()
    for item in dados:
        headers.update(item.keys())

    try:
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=sorted(list(headers)))
            writer.writeheader()
            writer.writerows(dados)
        print(f"[+] RELATORIO DE {prefixo.upper()} GERADO: {filename} ({len(dados)} registos)")
    except Exception as e:
        print(f"[!] Erro ao gravar ficheiro de {prefixo}: {e}")

if __name__ == "__main__":
    id_arg = sys.argv[1] if len(sys.argv) > 1 else None
    id_label = id_arg if id_arg else "Geral"

    # --- PROCESSAMENTO DE ANOMALIAS ---
    anomalias = buscar_dados_no_mongo("Anomalia", id_arg)
    gerar_csv(anomalias, "Anomalias", id_label)

    # --- PROCESSAMENTO DE OUTLIERS ---
    outliers = buscar_dados_no_mongo("Outlier", id_arg)
    gerar_csv(outliers, "Outliers", id_label)