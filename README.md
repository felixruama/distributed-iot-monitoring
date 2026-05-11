# Execução do Projeto


No PC2:

- CALL SP_CriarSimulacao(1, 'Teste com Alertas');

	mudar id para 0 e queipa para 7

-- Parâmetros: IDSimulacao, TempMin, TempMax, RuidoMax, Periodicidade, IntervaloAlertas(Segundos)

- CALL SP_ValidarParametros(1, 10.0, 24.0, 20.0, 1, 60);

python cloudToMySQL.py 1

CALL SP_IniciarSimulacao(1);

python MQTTToMySQL.py

No PC1: comecar conexao mongodb

python to_mongo.py

python MongoToMQTT.py

.\mazerun.exe 7 --broker broker.hivemq.com --portbroker 1883

