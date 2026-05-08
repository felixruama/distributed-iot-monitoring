-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql
-- Generation Time: May 07, 2026 at 11:44 PM
-- Server version: 8.0.45
-- PHP Version: 8.3.30

SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `labirinto_DB_ruama`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`%` PROCEDURE `SP_ApagarUtilizador` (IN `p_id` INT)   BEGIN
DELETE FROM utilizador WHERE IDUtilizador = p_id;

IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erro: Utilizador nao encontrado.';
ELSE
SELECT 'SUCESSO: Utilizador removido com sucesso!' AS Resultado;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_CriarSimulacao` (IN `p_IDUtilizador` INT, IN `p_Descricao` TEXT, IN `p_TempMax` DECIMAL(6,2), IN `p_TempMin` DECIMAL(6,2), IN `p_RuidoMax` DECIMAL(6,2), IN `p_Periodicidade` INT, IN `p_Intervalo` INT)   BEGIN
    DECLARE v_equipa INT DEFAULT 7;

    -- Mantemos a tua lógica de obter a equipa real
SELECT Equipa INTO v_equipa FROM utilizador WHERE IDUtilizador = p_IDUtilizador;

IF v_equipa IS NULL OR v_equipa = 0 THEN
        SET v_equipa = 7;
END IF;

    -- Inserimos TUDO de uma vez na tabela simulacao
INSERT INTO simulacao (
    Descricao, Equipa, Criador, SimulacaoIniciada, Pontos, Estado,
    TempMaxAlerta, TempMinAlerta, RuidoMaxAlerta, Periodicidade, SegundosIntervaloAlertas
)
VALUES (
           p_Descricao, v_equipa, p_IDUtilizador, 0, 0, '0',
           p_TempMax, p_TempMin, p_RuidoMax, p_Periodicidade, p_Intervalo
       );

SELECT LAST_INSERT_ID() AS IDSimulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_CriarUtilizador` (IN `p_Nome` VARCHAR(100), IN `p_Email` VARCHAR(50), IN `p_Password` VARCHAR(255), IN `p_Tipo` VARCHAR(50), IN `p_Telemovel` VARCHAR(12), IN `p_DataNascimento` DATE, IN `p_Equipa` INT)   BEGIN
    -- 1. Validação de Equipa
    IF p_Equipa IS NULL OR p_Equipa <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: O utilizador tem de pertencer a uma equipa válida (ID > 0).';
    -- 2. Verificação de Duplicados na Tabela
    ELSEIF EXISTS (SELECT 1 FROM utilizador WHERE Email = p_Email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Email ja registado na tabela.';
ELSE
        -- 3. INSERIR NA TABELA
        INSERT INTO utilizador (Nome, Telemovel, Tipo, Password, Email, DataNascimento, Equipa)
        VALUES (p_Nome, p_Telemovel, p_Tipo, p_Password, p_Email, p_DataNascimento, p_Equipa);

        -- 4. CRIAR UTILIZADOR NO MOTOR DO MYSQL
        SET @sql_create = CONCAT('CREATE USER ''', p_Email, '''@''%'' IDENTIFIED BY ''', p_Password, ''';');
PREPARE stmt_create FROM @sql_create; EXECUTE stmt_create; DEALLOCATE PREPARE stmt_create;

-- 5. MATRIZ DE PERMISSÕES DINÂMICA
SET @db = 'labirinto_DB_ruama';
        SET @usr = CONCAT('''', p_Email, '''@''%''');

        IF p_Tipo = 'Admin' THEN
            SET @qry = CONCAT('GRANT SELECT ON ', @db, '.ocupacaolabirinto TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.som TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.temperatura TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.corredor TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.marsami TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.medicoespassagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.mensagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.simulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT ALL PRIVILEGES ON ', @db, '.utilizador TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_EditarPerfil TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_ApagarUtilizador TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_CriarUtilizador TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

ELSEIF p_Tipo = 'Utilizador' THEN
            SET @qry = CONCAT('GRANT SELECT ON ', @db, '.ocupacaolabirinto TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.som TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.temperatura TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.corredor TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.marsami TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.medicoespassagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.mensagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.utilizador TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.simulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_EditarPerfil TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_ValidarLogin TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_CriarSimulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_ObterHistorico TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_VisualizarDetalhes_Historico TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_VisualizarDetalhes TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_ValidarParametros TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_IniciarSimulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

ELSEIF p_Tipo = 'Monitor Android' THEN
            SET @qry = CONCAT('GRANT SELECT ON ', @db, '.ocupacaolabirinto TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.som TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.temperatura TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.corredor TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.marsami TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.medicoespassagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.mensagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.simulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

ELSEIF p_Tipo = 'Migrador' THEN
            SET @qry = CONCAT('GRANT SELECT ON ', @db, '.ocupacaolabirinto TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT INSERT ON ', @db, '.som TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT INSERT ON ', @db, '.temperatura TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT, UPDATE ON ', @db, '.corredor TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT, UPDATE ON ', @db, '.marsami TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.medicoespassagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.mensagens TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT SELECT ON ', @db, '.simulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;

SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_RegistarPassagem TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_RegistarAlerta TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
SET @qry = CONCAT('GRANT EXECUTE ON PROCEDURE ', @db, '.SP_TerminarSimulacao TO ', @usr); PREPARE s FROM @qry; EXECUTE s;
END IF;

DEALLOCATE PREPARE s;
FLUSH PRIVILEGES;

SELECT LAST_INSERT_ID() AS IDUtilizador, 'Utilizador criado com a matriz de permissoes aplicada!' AS Mensagem;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_EditarPerfil` (IN `p_IDUtilizador` INT, IN `p_JSON` JSON)   BEGIN
    -- Declaramos tudo como VARCHAR para que o MySQL não crashe ao ler o JSON!
    DECLARE v_Nome VARCHAR(100);
    DECLARE v_Telemovel VARCHAR(12);
    DECLARE v_DataNascimento VARCHAR(20); -- <--- ALTERADO PARA VARCHAR
    DECLARE v_ID_Alvo INT;

    SET v_ID_Alvo = JSON_UNQUOTE(JSON_EXTRACT(p_JSON, '$.IDUtilizador'));
    SET v_Nome = JSON_UNQUOTE(JSON_EXTRACT(p_JSON, '$.Nome'));
    SET v_Telemovel = JSON_UNQUOTE(JSON_EXTRACT(p_JSON, '$.Telemovel'));
    SET v_DataNascimento = JSON_UNQUOTE(JSON_EXTRACT(p_JSON, '$.DataNascimento'));

    IF (p_IDUtilizador != v_ID_Alvo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro de Seguranca: Nao tens permissao para editar o perfil desta conta!';
ELSE
        -- Agora sim, na hora de gravar é que limpamos a sujidade
UPDATE utilizador
SET Nome = v_Nome,
    Telemovel = NULLIF(v_Telemovel, ''),
    -- Se vier vazio, manda NULL para a BD. Senão, manda a data.
    DataNascimento = IF(v_DataNascimento = '' OR v_DataNascimento = 'null', NULL, v_DataNascimento)
WHERE IDUtilizador = p_IDUtilizador;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_IniciarSimulacao` (IN `p_IDSimulacao` INT)   BEGIN
UPDATE simulacao SET Estado = '1', DataHoraInicio = CURRENT_TIMESTAMP, SimulacaoIniciada = 1 WHERE IDSimulacao = p_IDSimulacao;
IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Simulacao nao encontrada.';
ELSE
SELECT 'SUCESSO: Simulacao iniciada com sucesso!' AS Resultado;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterHistorico` ()   BEGIN
SELECT
    res.IDSimulacao,
    MAX(res.Descricao) AS Descricao,
    MAX(res.Estado) AS Estado,
    MAX(res.Criador) AS Criador,
    u.Nome AS NomeCriador,
    MAX(res.DataHoraInicio) AS DataHoraInicio,
    MAX(res.DataHoraFim) AS DataHoraFim
FROM (
         -- Parte 1: Uniformiza os textos da tabela simulacao para utf8mb4
         SELECT
             IDSimulacao,
             CONVERT(Descricao USING utf8mb4) AS Descricao,
             CONVERT(Estado USING utf8mb4) AS Estado,
             Criador,
             NULL AS DataHoraInicio,
             NULL AS DataHoraFim
         FROM simulacao
         WHERE Estado = '2'

         UNION ALL

         -- Parte 2: Uniformiza os textos da tabela de historico para utf8mb4
         SELECT
             IDSimulacao,
             CONVERT(Descricao USING utf8mb4) AS Descricao,
             CONVERT(Estado USING utf8mb4) AS Estado,
             Criador,
             DataHoraInicio,
             DataHoraFim
         FROM historico_simulacao
     ) AS res
         LEFT JOIN utilizador u ON res.Criador = u.IDUtilizador
GROUP BY res.IDSimulacao, u.Nome
ORDER BY res.IDSimulacao DESC;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterPerfil` (IN `p_IDUtilizador` INT)   BEGIN
SELECT IDUtilizador, Nome, Email, Telemovel, DataNascimento
FROM utilizador
WHERE IDUtilizador = p_IDUtilizador;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterSimulacoesAtivas` ()   BEGIN
SELECT s.IDSimulacao, s.Descricao, s.Estado, s.Criador, u.Nome AS NomeCriador
FROM simulacao s
         LEFT JOIN utilizador u ON s.Criador = u.IDUtilizador
WHERE s.Estado IN ('0', '1')
ORDER BY s.IDSimulacao DESC;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_RegistarAlerta` (IN `p_id_simulacao` INT, IN `p_tipo_sensor` VARCHAR(10), IN `p_valor` DECIMAL(6,2), IN `p_tipo_alerta` VARCHAR(50), IN `p_texto_mensagem` TEXT, IN `p_hora_sensor` VARCHAR(50))   BEGIN
    DECLARE v_intervalo INT DEFAULT 60;
    DECLARE v_ultimo_valor DECIMAL(6,2) DEFAULT NULL;
    DECLARE v_ultima_hora TIMESTAMP DEFAULT NULL;
    DECLARE v_segundos_passados INT DEFAULT 0;

    -- Obter o intervalo (cooldown) definido na simulação
SELECT SegundosIntervaloAlertas INTO v_intervalo
FROM simulacao
WHERE IDSimulacao = p_id_simulacao;

-- Obter a hora e o valor do ÚLTIMO alerta deste tipo específico (ex: só 'TEMP' ou só 'RUIDO')
SELECT Leitura, HoraEscrita INTO v_ultimo_valor, v_ultima_hora
FROM mensagens
WHERE Sensor = p_tipo_sensor AND TipoAlerta = p_tipo_alerta
ORDER BY HoraEscrita DESC
    LIMIT 1;

-- Calcular tempo passado
IF v_ultima_hora IS NOT NULL THEN
        SET v_segundos_passados = TIMESTAMPDIFF(SECOND, v_ultima_hora, NOW());
END IF;

    -- LÓGICA ANTI-SPAM (A OR é a magia aqui):
    -- 1. Se o cooldown não passou (< v_intervalo) -> BLOQUEIA
    -- 2. OU Se o valor for igual ao último (v_ultimo_valor = p_valor) -> BLOQUEIA
    IF v_ultima_hora IS NOT NULL AND (v_segundos_passados < v_intervalo OR v_ultimo_valor = p_valor) THEN
SELECT 'Alerta suprimido pelo mecanismo anti-spam.' AS Resultado;
ELSE
        -- Passou nos testes: O cooldown expirou E o valor evoluiu (subiu ou desceu)
        INSERT INTO mensagens (Hora, Sensor, Leitura, TipoAlerta, Msg, HoraEscrita, IDSimulacao)
        VALUES (p_hora_sensor, p_tipo_sensor, p_valor, p_tipo_alerta, p_texto_mensagem, NOW(), p_id_simulacao);

SELECT 'Alerta registado com sucesso.' AS Resultado;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_RegistarPassagem` (IN `p_id_simulacao` INT, IN `p_id_marsami` INT, IN `p_origem` INT, IN `p_destino` INT, IN `p_status` INT, IN `p_idmongo` VARCHAR(24))   BEGIN
    -- Determinar se o Marsami é Ímpar (1) ou Par (0)
    DECLARE v_parity INT;
    SET v_parity = p_id_marsami % 2;

    -- 1. Registar a passagem na tabela medicoespassagens
INSERT INTO medicoespassagens (Hora, SalaOrigem, SalaDestino, IDMarsami, Status, IDSimulacao, IDMongo)
VALUES (NOW(), p_origem, p_destino, p_id_marsami, p_status, p_id_simulacao, p_idmongo);

-- 2. Retirar um Marsami da sala de ORIGEM na tabela ocupacaolabirinto
-- Usamos GREATEST para garantir que o número nunca fica negativo (abaixo de 0)
IF v_parity = 1 THEN
UPDATE ocupacaolabirinto
SET NumeroMarsamisOdd = GREATEST(NumeroMarsamisOdd - 1, 0)
WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
ELSE
UPDATE ocupacaolabirinto
SET NumeroMarsamisEven = GREATEST(NumeroMarsamisEven - 1, 0)
WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
END IF;

    -- 3. Adicionar um Marsami à sala de DESTINO na tabela ocupacaolabirinto
    -- Usamos ON DUPLICATE KEY UPDATE para criar a linha caso a sala ainda não exista na tabela
    IF v_parity = 1 THEN
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao)
        VALUES (1, 0, p_destino, p_id_simulacao)
        ON DUPLICATE KEY UPDATE NumeroMarsamisOdd = NumeroMarsamisOdd + 1;
ELSE
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao)
        VALUES (0, 1, p_destino, p_id_simulacao)
        ON DUPLICATE KEY UPDATE NumeroMarsamisEven = NumeroMarsamisEven + 1;
END IF;

    -- 4. Atualizar a localização e o estado Cansado do Marsami
    -- Se o status for 2, Cansado = 1 (true). Caso contrário, Cansado = 0 (false).
UPDATE marsami
SET IDSala = p_destino,
    Cansado = CASE WHEN p_status = 2 THEN 1 ELSE 0 END
WHERE IDMarsami = p_id_marsami AND IDSimulacao = p_id_simulacao;

END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_TerminarSimulacao` (IN `p_id_simulacao` INT)   BEGIN
UPDATE simulacao SET Estado = '2', DataHoraFim = CURRENT_TIMESTAMP WHERE IDSimulacao = p_id_simulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ValidarLogin` (IN `p_Email` VARCHAR(50), IN `p_Password` VARCHAR(255))   BEGIN
    DECLARE v_Existe INT;
    DECLARE v_Equipa INT;
    DECLARE v_ID INT; -- Nova variável para guardar o ID

    -- Descobre se existe e guarda o ID e a Equipa nas variáveis
SELECT COUNT(*), MAX(IDUtilizador), MAX(Equipa) INTO v_Existe, v_ID, v_Equipa
FROM utilizador
WHERE Email = p_Email AND Password = SHA2(p_Password, 256);

IF v_Existe = 1 THEN
        -- AGORA SIM: Devolvemos também o IDUtilizador!
SELECT
    'Sucesso: Login válido' AS Mensagem,
    p_Email AS Email,
    v_Equipa AS Equipa,
    v_ID AS IDUtilizador;
ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Credenciais inválidas.';
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ValidarParametros` (IN `p_IDSimulacao` INT, IN `p_IDUtilizador` INT, IN `p_TempMax` INT, IN `p_TempMin` INT, IN `p_RuidoMax` INT, IN `p_Periodicidade` INT, IN `p_intervaloAlertas` INT)   BEGIN
    DECLARE v_estado ENUM('0','1','2');
    DECLARE v_criador INT;

    -- Procuramos o estado e o criador ao mesmo tempo
SELECT Estado, Criador INTO v_estado, v_criador
FROM simulacao
WHERE IDSimulacao = p_IDSimulacao;

-- 1. Verificação de Existência
IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Simulacao nao encontrada.';

    -- 2. Verificação de Segurança: Só o dono mexe
    ELSEIF v_criador != p_IDUtilizador THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Nao tens permissao para editar os parametros desta conta.';

    -- 3. Verificação de Estado: Só permite editar se estiver em 'Criada' (0)
    ELSEIF v_estado != '0' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: So e possivel editar parametros de simulacoes no estado Criada.';

    -- 4. Verificação de Temperaturas
    ELSEIF p_TempMin >= p_TempMax THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Temperatura minima deve ser inferior a temperatura maxima.';

    -- 5. Verificação de Números Negativos
    ELSEIF p_Periodicidade < 0 OR p_intervaloAlertas < 0 OR p_RuidoMax < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Parametros numericos devem ser nao negativos.';

    -- 6. Sucesso: Atualização
ELSE
UPDATE simulacao SET
                     TempMinAlerta = p_TempMin,
                     TempMaxAlerta = p_TempMax,
                     RuidoMaxAlerta = p_RuidoMax,
                     Periodicidade = p_Periodicidade,
                     SegundosIntervaloAlertas = p_intervaloAlertas
WHERE IDSimulacao = p_IDSimulacao;
END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_VisualizarDetalhes` (IN `p_IDSimulacao` INT)   BEGIN
SELECT
    s.IDSimulacao,
    s.Descricao,
    s.Estado,
    s.Criador,
    -- Forçamos os nomes para baterem certo com o PHP
    s.TempMinAlerta AS TempMin,
    s.TempMaxAlerta AS TempMax,
    s.RuidoMaxAlerta AS RuidoMax,
    s.Periodicidade AS Periodicidade,
    s.SegundosIntervaloAlertas AS IntervaloAlertas,
    u.Nome AS NomeCriador
FROM simulacao s
         LEFT JOIN utilizador u ON s.Criador = u.IDUtilizador
WHERE s.IDSimulacao = p_IDSimulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_VisualizarDetalhes_Historico` (IN `p_IDSimulacao` INT)   BEGIN
SELECT
    res.IDSimulacao,
    MAX(res.Descricao) AS Descricao,
    MAX(res.Estado) AS Estado,
    MAX(res.Criador) AS Criador,
    u.Nome AS NomeCriador,
    MAX(res.DataHoraInicio) AS DataHoraInicio,
    MAX(res.DataHoraFim) AS DataHoraFim,
    MAX(res.TempMin) AS TempMin,
    MAX(res.TempMax) AS TempMax,
    MAX(res.RuidoMax) AS RuidoMax
FROM (
         -- Parte 1: Buscar na tabela simulacao
         SELECT
             IDSimulacao,
             CONVERT(Descricao USING utf8mb4) AS Descricao,
             CONVERT(Estado USING utf8mb4) AS Estado,
             Criador,
             NULL AS DataHoraInicio,
             NULL AS DataHoraFim,
             TempMinAlerta AS TempMin,
             TempMaxAlerta AS TempMax,
             RuidoMaxAlerta AS RuidoMax
         FROM simulacao
         WHERE IDSimulacao = p_IDSimulacao AND Estado = '2'

         UNION ALL

         -- Parte 2: Buscar na tabela historico_simulacao
         -- (Assumindo que a tua tabela de histórico tem estas colunas gravadas)
         SELECT
             IDSimulacao,
             CONVERT(Descricao USING utf8mb4) AS Descricao,
             CONVERT(Estado USING utf8mb4) AS Estado,
             Criador,
             DataHoraInicio,
             DataHoraFim,
             TempMinAlerta AS TempMin,
             TempMaxAlerta AS TempMax,
             RuidoMaxAlerta AS RuidoMax
         FROM historico_simulacao
         WHERE IDSimulacao = p_IDSimulacao
     ) AS res
         LEFT JOIN utilizador u ON res.Criador = u.IDUtilizador
GROUP BY res.IDSimulacao, u.Nome;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `corredor`
--

CREATE TABLE `corredor` (
                            `IDCorredor` int NOT NULL,
                            `Aberto` tinyint(1) NOT NULL,
                            `IDSalaA` int NOT NULL,
                            `IDSalaB` int NOT NULL,
                            `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `corredor`
--
DELIMITER $$
CREATE TRIGGER `trg_Manter_Fechado` BEFORE UPDATE ON `corredor` FOR EACH ROW BEGIN
    DECLARE v_estado ENUM('0','1','2');

    IF NEW.Aberto = 1 AND OLD.Aberto = 0 THEN
    SELECT Estado INTO v_estado FROM simulacao WHERE IDSimulacao = OLD.IDSimulacao;
    -- 'Terminada' agora é '2'
    IF v_estado = '2' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Nao e possivel reabrir corredores apos terminada a simulacao.';
END IF;
END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `fila_terminacao`
--

CREATE TABLE `fila_terminacao` (
                                   `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `historico_medicoespassagens`
--

CREATE TABLE `historico_medicoespassagens` (
                                               `IDMedicao` int NOT NULL,
                                               `Hora` timestamp NULL DEFAULT NULL,
                                               `SalaOrigem` int NOT NULL,
                                               `SalaDestino` int NOT NULL,
                                               `IDMarsami` int NOT NULL,
                                               `Status` int NOT NULL,
                                               `IDMongo` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
                                               `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `historico_ocupacaolabirinto`
--

CREATE TABLE `historico_ocupacaolabirinto` (
                                               `NumeroMarsamisOdd` int NOT NULL,
                                               `NumeroMarsamisEven` int NOT NULL,
                                               `Sala` int NOT NULL,
                                               `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `historico_simulacao`
--

CREATE TABLE `historico_simulacao` (
                                       `IDSimulacao` int NOT NULL,
                                       `Descricao` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
                                       `Equipa` int NOT NULL,
                                       `DataHoraInicio` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `DataHoraFim` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       `SimulacaoIniciada` tinyint(1) NOT NULL,
                                       `Pontos` int DEFAULT NULL,
                                       `Criador` int NOT NULL DEFAULT '0',
                                       `TempMaxAlerta` decimal(6,2) DEFAULT NULL,
                                       `TempMinAlerta` decimal(6,2) DEFAULT NULL,
                                       `RuidoMaxAlerta` decimal(6,2) DEFAULT NULL,
                                       `SegundosIntervaloAlertas` int DEFAULT '60',
                                       `MargemToleranciaOutlier` decimal(6,2) DEFAULT NULL,
                                       `Periodicidade` int DEFAULT NULL,
                                       `Estado` enum('0','1','2') NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `marsami`
--

CREATE TABLE `marsami` (
                           `IDMarsami` int NOT NULL,
                           `Cansado` tinyint(1) NOT NULL,
                           `IDSala` int NOT NULL,
                           `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `marsami`
--
DELIMITER $$
CREATE TRIGGER `trg_Verificar_Cansados` AFTER UPDATE ON `marsami` FOR EACH ROW BEGIN
    DECLARE v_nao_cansados INT DEFAULT 0;

    -- 1. Só agimos se o Marsami acabou de ficar cansado nesta atualização
    IF NEW.Cansado = 1 AND OLD.Cansado = 0 THEN

        -- 2. Contamos quantos Marsamis ainda NÃO estão cansados nesta simulação
    SELECT COUNT(*) INTO v_nao_cansados
    FROM marsami
    WHERE IDSimulacao = OLD.IDSimulacao AND Cansado = 0;

    -- 3. Se não sobrar nenhum robô ativo, INSERIMOS NA FILA!
    IF v_nao_cansados = 0 THEN
            INSERT IGNORE INTO fila_terminacao (IDSimulacao) VALUES (OLD.IDSimulacao);
END IF;

END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `medicoespassagens`
--

CREATE TABLE `medicoespassagens` (
                                     `IDMedicao` int NOT NULL,
                                     `IDSimulacao` int NOT NULL,
                                     `IDMarsami` int DEFAULT NULL,
                                     `SalaOrigem` int DEFAULT NULL,
                                     `SalaDestino` int DEFAULT NULL,
                                     `Status` varchar(50) DEFAULT NULL,
                                     `IDMongo` varchar(50) DEFAULT NULL,
                                     `DataMedicao` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mensagens`
--

CREATE TABLE `mensagens` (
                             `ID` int NOT NULL,
                             `Hora` varchar(50) DEFAULT NULL,
                             `Sensor` varchar(10) DEFAULT NULL,
                             `Leitura` decimal(6,2) DEFAULT NULL,
                             `TipoAlerta` varchar(50) DEFAULT NULL,
                             `Msg` text,
                             `HoraEscrita` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
                             `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ocupacaolabirinto`
--

CREATE TABLE `ocupacaolabirinto` (
                                     `NumeroMarsamisOdd` int NOT NULL,
                                     `NumeroMarsamisEven` int NOT NULL,
                                     `Sala` int NOT NULL,
                                     `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `simulacao`
--

CREATE TABLE `simulacao` (
                             `IDSimulacao` int NOT NULL,
                             `Descricao` varchar(255) DEFAULT NULL,
                             `Equipa` int NOT NULL,
                             `DataHoraInicio` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                             `DataHoraFim` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                             `SimulacaoIniciada` tinyint(1) NOT NULL,
                             `Pontos` decimal(6,1) DEFAULT NULL,
                             `Criador` int NOT NULL,
                             `TempMaxAlerta` decimal(6,2) DEFAULT NULL,
                             `TempMinAlerta` decimal(6,2) DEFAULT NULL,
                             `RuidoMaxAlerta` decimal(6,2) DEFAULT NULL,
                             `SegundosIntervaloAlertas` int DEFAULT '60',
                             `Periodicidade` int DEFAULT NULL,
                             `Estado` enum('0','1','2') NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `som`
--

CREATE TABLE `som` (
                       `IDSom` int NOT NULL,
                       `Hora` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
                       `Som` decimal(6,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `temperatura`
--

CREATE TABLE `temperatura` (
                               `IDTemperatura` int NOT NULL,
                               `Hora` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
                               `Temperatura` decimal(6,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `utilizador`
--

CREATE TABLE `utilizador` (
                              `IDUtilizador` int NOT NULL,
                              `Password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
                              `Nome` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
                              `Telemovel` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
                              `Tipo` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
                              `Email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
                              `DataNascimento` date DEFAULT NULL,
                              `Equipa` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `utilizador`
--

INSERT INTO `utilizador` (`IDUtilizador`, `Password`, `Nome`, `Telemovel`, `Tipo`, `Email`, `DataNascimento`, `Equipa`) VALUES
                                                                                                                            (1, '', 'Ana Maria Braga', NULL, '', 'ana@email.com', NULL, 0),
                                                                                                                            (2, '', 'Bruno Ramos', NULL, '', 'bruno@email.com', NULL, 0),
                                                                                                                            (3, '', 'Utilizador PHP 1', NULL, 'web', 'user1_php', NULL, 1),
                                                                                                                            (4, '', 'Utilizador PHP 2', NULL, 'web', 'user2_php', NULL, 2),
                                                                                                                            (7, '79809644a830ef92424a66227252b87bbdfb633a9dab18ba450c1b8d35665f20', 'ola', NULL, 'web', 'rrlfx@iscte.pt', NULL, 0),
                                                                                                                            (9, 'b3a8e0e1f9ab1bfe3a36f231f676f78bb30a519d2b21e6c530c0eee8ebb4a5d0', 'Maria Completa', '912345678', 'web', 'maria@teste.com', '1998-05-20', 0),
                                                                                                                            (10, '35a9e381b1a27567549b5f8a6f783c167ebf809f1c4d6a9e367240484d8ce281', 'Ricardo Tel', '933444555', 'web', 'ric@teste.com', NULL, 0),
                                                                                                                            (11, 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'Joao Com Equipa', '912345678', 'web', 'joao.equipa@teste.com', '2000-01-01', 1),
                                                                                                                            (12, '46070d4bf934fb0d4b06d9e2c46e346944e322444900a435d7d9a95e6d7435f5', 'teste', '123', 'web', 'teste', '2020-11-11', 7),
                                                                                                                            (13, '9b8769a4a742959a2d0298c36fb70623f2dfacda8436237df08d8dfd5b37374c', 'Novo Dev', NULL, 'web', 'dev@lab.com', NULL, 1),
                                                                                                                            (14, 'f91a799a01ebac97c8995f50381b5be0d43ca7eb0c6a6c6bc07603c5a922d1fa', 'ola', '56566565', 'web', 'teste2@iscte.pt', '2020-12-12', 7),
                                                                                                                            (15, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Chefe Supremo', '919999999', 'Admin', 'admin.master@lab.pt', '1980-05-20', 1),
                                                                                                                            (17, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Chefe Supremo', '000000000', 'Admin', 'admin.grande@lab.pt', '1980-07-27', 1),
                                                                                                                            (18, 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'Teste do Admin: Criar pela SP', NULL, 'Utilizador', 'UserFeitoPorAdim@lab.pt', NULL, 1),
                                                                                                                            (19, 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'Nome Editado Com Sucesso', NULL, 'Utilizador', 'direto@lab.pt', NULL, 1),
                                                                                                                            (21, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'mudei', '037167819', 'Utilizador', 'jogador.teste@lab.pt', '2000-01-07', 2),
                                                                                                                            (24, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Novo Admin Supremo', '999888777', 'Admin', 'admin2@lab.pt', '1990-01-01', 1),
                                                                                                                            (25, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Robo Marsami', NULL, 'Migrador', 'robo.migrador2@lab.pt', NULL, 1),
                                                                                                                            (26, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Tablet Sala 1', NULL, 'Monitor Android', 'monitor@lab.pt', NULL, 1),
                                                                                                                            (27, '55a5e9e78207b4df8699d60886fa070079463547b095d1a05bc719bb4e6cd251', 'Tablet Sala 1', NULL, 'Monitor Android', 'monitor2@lab.pt', NULL, 1);

--
-- Triggers `utilizador`
--
DELIMITER $$
CREATE TRIGGER `Adicionar_Password` BEFORE INSERT ON `utilizador` FOR EACH ROW BEGIN
    SET NEW.Password = SHA2(NEW.Password, 256);
END
    $$
DELIMITER ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `corredor`
--
ALTER TABLE `corredor`
    ADD PRIMARY KEY (`IDCorredor`),
  ADD KEY `fk_corredor_simulacao` (`IDSimulacao`);

--
-- Indexes for table `fila_terminacao`
--
ALTER TABLE `fila_terminacao`
    ADD PRIMARY KEY (`IDSimulacao`);

--
-- Indexes for table `historico_medicoespassagens`
--
ALTER TABLE `historico_medicoespassagens`
    ADD PRIMARY KEY (`IDMedicao`,`IDSimulacao`),
  ADD KEY `fk_passagens_simulacao` (`IDSimulacao`),
  ADD KEY `fk_passagens_salaO` (`SalaOrigem`),
  ADD KEY `fk_passagens_salaD` (`SalaDestino`),
  ADD KEY `fk_passagens_marsami` (`IDMarsami`);

--
-- Indexes for table `historico_ocupacaolabirinto`
--
ALTER TABLE `historico_ocupacaolabirinto`
    ADD PRIMARY KEY (`Sala`,`IDSimulacao`),
  ADD KEY `fk_ocupacao_sala` (`Sala`),
  ADD KEY `fk_ocupacao_simulacao` (`IDSimulacao`);

--
-- Indexes for table `historico_simulacao`
--
ALTER TABLE `historico_simulacao`
    ADD PRIMARY KEY (`IDSimulacao`);

--
-- Indexes for table `marsami`
--
ALTER TABLE `marsami`
    ADD PRIMARY KEY (`IDMarsami`),
  ADD KEY `fk_marsami_simulacao` (`IDSimulacao`);

--
-- Indexes for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
    ADD PRIMARY KEY (`IDMedicao`),
  ADD KEY `fk_passagens_simulacao_ref` (`IDSimulacao`),
  ADD KEY `fk_passagens_marsami_ref` (`IDMarsami`);

--
-- Indexes for table `mensagens`
--
ALTER TABLE `mensagens`
    ADD PRIMARY KEY (`ID`),
  ADD KEY `fk_mensagens_simulacao` (`IDSimulacao`);

--
-- Indexes for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
    ADD PRIMARY KEY (`Sala`,`IDSimulacao`),
  ADD KEY `fk_ocupacao_simulacao` (`IDSimulacao`);

--
-- Indexes for table `simulacao`
--
ALTER TABLE `simulacao`
    ADD PRIMARY KEY (`IDSimulacao`),
  ADD KEY `fk_simulacao_criador` (`Criador`);

--
-- Indexes for table `som`
--
ALTER TABLE `som`
    ADD PRIMARY KEY (`IDSom`);

--
-- Indexes for table `temperatura`
--
ALTER TABLE `temperatura`
    ADD PRIMARY KEY (`IDTemperatura`);

--
-- Indexes for table `utilizador`
--
ALTER TABLE `utilizador`
    ADD PRIMARY KEY (`IDUtilizador`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `corredor`
--
ALTER TABLE `corredor`
    MODIFY `IDCorredor` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
    MODIFY `IDMedicao` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mensagens`
--
ALTER TABLE `mensagens`
    MODIFY `ID` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `simulacao`
--
ALTER TABLE `simulacao`
    MODIFY `IDSimulacao` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `som`
--
ALTER TABLE `som`
    MODIFY `IDSom` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `temperatura`
--
ALTER TABLE `temperatura`
    MODIFY `IDTemperatura` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `utilizador`
--
ALTER TABLE `utilizador`
    MODIFY `IDUtilizador` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `corredor`
--
ALTER TABLE `corredor`
    ADD CONSTRAINT `fk_corredor_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `marsami`
--
ALTER TABLE `marsami`
    ADD CONSTRAINT `fk_marsami_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
    ADD CONSTRAINT `fk_passagens_marsami_ref` FOREIGN KEY (`IDMarsami`) REFERENCES `marsami` (`IDMarsami`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_passagens_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `mensagens`
--
ALTER TABLE `mensagens`
    ADD CONSTRAINT `fk_mensagens_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
    ADD CONSTRAINT `fk_ocupacao_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `simulacao`
--
ALTER TABLE `simulacao`
    ADD CONSTRAINT `fk_simulacao_criador_ref` FOREIGN KEY (`Criador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE CASCADE ON UPDATE CASCADE;
SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

