# Execução do Projeto


No PC2:

-- Parâmetros: (ID_Utilizador_Criador, Descrição, TempMax, TempMin, RuidoMax, Periodicidade, IntervaloAlertas)
CALL SP_CriarSimulacao(12, 'Teste com Alertas', 30.0, 15.0, 80.0, 5, 60);

-- Parâmetros: (ID_Simulacao, ID_Utilizador_Criador, TempMax, TempMin, RuidoMax, Periodicidade, IntervaloAlertas)
CALL SP_ValidarParametros(1, 12, 32.0, 18.0, 85.0, 5, 60);

python cloudToMySQL.py 1

CALL SP_IniciarSimulacao(1);

python MQTTToMySQL.py

No PC1: comecar conexao mongodb

python to_mongo.py

python MongoToMQTT.py

.\mazerun.exe 7 --broker broker.hivemq.com --portbroker 1883



No fim:

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE som;
TRUNCATE TABLE temperatura;
TRUNCATE TABLE mensagens;
TRUNCATE TABLE medicoespassagens;
TRUNCATE TABLE ocupacaolabirinto;
TRUNCATE TABLE corredor;
TRUNCATE TABLE marsami;
TRUNCATE TABLE simulacao;

SET FOREIGN_KEY_CHECKS = 1;