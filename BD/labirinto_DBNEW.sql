-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql
-- Tempo de geração: 11-Maio-2026 às 14:46
-- Versão do servidor: 8.0.45
-- versão do PHP: 8.3.30

SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de dados: `labirinto_DBNEW`
--
CREATE DATABASE IF NOT EXISTS `labirinto_DBNEW` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `labirinto_DBNEW`;

DELIMITER $$
--
-- Procedimentos
--
DROP PROCEDURE IF EXISTS `SP_ApagarUtilizador`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_ApagarUtilizador` (IN `p_id` INT)   BEGIN
DELETE FROM utilizador WHERE IDUtilizador = p_id;

IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erro: Utilizador nao encontrado.';
ELSE
SELECT 'SUCESSO: Utilizador removido com sucesso!' AS Resultado;
END IF;
END$$

DROP PROCEDURE IF EXISTS `SP_CriarSimulacao`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_CriarSimulacao` (IN `p_IDUtilizador` INT, IN `p_Descricao` TEXT, IN `p_TempMax` DECIMAL(6,2), IN `p_TempMin` DECIMAL(6,2), IN `p_RuidoMax` DECIMAL(6,2), IN `p_Periodicidade` INT, IN `p_Intervalo` INT)   BEGIN
    DECLARE v_equipa INT DEFAULT 7;

    -- Mantemos a tua lógica de obter a equipa real
    SELECT Equipa INTO v_equipa FROM utilizador WHERE IDUtilizador = p_IDUtilizador;

    IF v_equipa IS NULL OR v_equipa = 0 THEN
        SET v_equipa = 7;
    END IF;

    -- Inserimos TUDO de uma vez na tabela simulacao (SEM O CAMPO SimulacaoIniciada)
    INSERT INTO simulacao (
        Descricao, Equipa, Criador, Pontos, Estado,
        TempMaxAlerta, TempMinAlerta, RuidoMaxAlerta, Periodicidade, SegundosIntervaloAlertas
    )
    VALUES (
        p_Descricao, v_equipa, p_IDUtilizador, 0, '0',
        p_TempMax, p_TempMin, p_RuidoMax, p_Periodicidade, p_Intervalo
    );

    SELECT LAST_INSERT_ID() AS IDSimulacao;
END$$

DROP PROCEDURE IF EXISTS `SP_CriarUtilizador`$$
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

DROP PROCEDURE IF EXISTS `SP_EditarPerfil`$$
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

DROP PROCEDURE IF EXISTS `SP_IniciarSimulacao`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_IniciarSimulacao` (IN `p_IDSimulacao` INT)   BEGIN
    DECLARE v_simulacoes_ativas INT DEFAULT 0;
    DECLARE v_simulacoes_terminadas INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        RESIGNAL; 
    END;

    START TRANSACTION;

    -- BARREIRA DE SEGURANÇA
    SELECT COUNT(*) INTO v_simulacoes_ativas FROM simulacao WHERE Estado = '1';
    
    IF v_simulacoes_ativas > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Já existe uma simulação a decorrer. Termine-a antes de iniciar uma nova.';
    END IF;

    -- EXPORTAR DADOS 
    SELECT COUNT(*) INTO v_simulacoes_terminadas FROM simulacao WHERE Estado = '2';
    
    IF v_simulacoes_terminadas > 0 THEN
        
        INSERT INTO historico_simulacao (IDSimulacao, Descricao, Equipa, DataHoraInicio, DataHoraFim, Pontos, Criador, TempMaxAlerta, TempMinAlerta, RuidoMaxAlerta, SegundosIntervaloAlertas, Periodicidade, Estado)
        SELECT IDSimulacao, Descricao, Equipa, DataHoraInicio, DataHoraFim, Pontos, Criador, TempMaxAlerta, TempMinAlerta, RuidoMaxAlerta, SegundosIntervaloAlertas, Periodicidade, Estado
        FROM simulacao WHERE Estado = '2';

        INSERT INTO historico_medicoespassagens (IDMedicao, Hora, SalaOrigem, SalaDestino, IDMarsami, Status, IDMongo, IDSimulacao)
        SELECT IDMedicao, DataMedicao, SalaOrigem, SalaDestino, IDMarsami, Status, IDMongo, IDSimulacao
        FROM medicoespassagens
        WHERE IDSimulacao IN (SELECT IDSimulacao FROM simulacao WHERE Estado = '2');

        INSERT INTO historico_ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao)
        SELECT NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao
        FROM ocupacaolabirinto
        WHERE IDSimulacao IN (SELECT IDSimulacao FROM simulacao WHERE Estado = '2');

        -- LIMPEZA DAS TABELAS "VIVAS"
        DELETE FROM som;
        DELETE FROM temperatura;
        DELETE FROM simulacao WHERE Estado = '2';

    END IF;

    -- INICIAR A NOVA SIMULAÇÃO 
    UPDATE simulacao 
    SET Estado = '1', DataHoraInicio = CURRENT_TIMESTAMP
    WHERE IDSimulacao = p_IDSimulacao;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Simulação não encontrada.';
    END IF;

    COMMIT;
    
    SELECT 'SUCESSO: Simulação iniciada. Tabela de histórico atualizada e lixo limpo!' AS Resultado;

END$$

DROP PROCEDURE IF EXISTS `SP_ObterHistorico`$$
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

DROP PROCEDURE IF EXISTS `SP_ObterPerfil`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterPerfil` (IN `p_IDUtilizador` INT)   BEGIN
SELECT IDUtilizador, Nome, Email, Telemovel, DataNascimento
FROM utilizador
WHERE IDUtilizador = p_IDUtilizador;
END$$

DROP PROCEDURE IF EXISTS `SP_ObterSimulacoesAtivas`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterSimulacoesAtivas` ()   BEGIN
SELECT s.IDSimulacao, s.Descricao, s.Estado, s.Criador, u.Nome AS NomeCriador
FROM simulacao s
         LEFT JOIN utilizador u ON s.Criador = u.IDUtilizador
WHERE s.Estado IN ('0', '1')
ORDER BY s.IDSimulacao DESC;
END$$

DROP PROCEDURE IF EXISTS `SP_RegistarAlerta`$$
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

DROP PROCEDURE IF EXISTS `SP_RegistarPassagem`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_RegistarPassagem` (IN `p_id_simulacao` INT, IN `p_id_marsami` INT, IN `p_origem` INT, IN `p_destino` INT, IN `p_status` INT, IN `p_idmongo` VARCHAR(24))   BEGIN
    DECLARE v_parity INT;

    -- =========================================================================
    -- O "AIRBAG": Cancela tudo se houver falha a meio do processo!
    -- =========================================================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Iniciar o modo "Tudo ou Nada"
    START TRANSACTION;

    -- Determinar se o Marsami é Ímpar (1) ou Par (0)
    SET v_parity = p_id_marsami % 2;

    -- 1. Registar a passagem
    INSERT INTO medicoespassagens (Hora, SalaOrigem, SalaDestino, IDMarsami, Status, IDSimulacao, IDMongo)
    VALUES (NOW(), p_origem, p_destino, p_id_marsami, p_status, p_id_simulacao, p_idmongo);

    -- 2. Retirar o Marsami da sala de ORIGEM 
    IF v_parity = 1 THEN
        UPDATE ocupacaolabirinto SET NumeroMarsamisOdd = GREATEST(NumeroMarsamisOdd - 1, 0) WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
    ELSE
        UPDATE ocupacaolabirinto SET NumeroMarsamisEven = GREATEST(NumeroMarsamisEven - 1, 0) WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
    END IF;

    -- 3. Adicionar o Marsami à sala de DESTINO 
    IF v_parity = 1 THEN
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao) VALUES (1, 0, p_destino, p_id_simulacao) ON DUPLICATE KEY UPDATE NumeroMarsamisOdd = NumeroMarsamisOdd + 1;
    ELSE
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao) VALUES (0, 1, p_destino, p_id_simulacao) ON DUPLICATE KEY UPDATE NumeroMarsamisEven = NumeroMarsamisEven + 1;
    END IF;

    -- 4. Atualizar a localização e o estado Cansado do Marsami
    UPDATE marsami SET IDSala = p_destino, Cansado = CASE WHEN p_status = 2 THEN 1 ELSE 0 END WHERE IDMarsami = p_id_marsami AND IDSimulacao = p_id_simulacao;

    -- Se chegou aqui sem crashar, grava definitivamente as 4 alterações ao mesmo tempo!
    COMMIT;

END$$

DROP PROCEDURE IF EXISTS `SP_TerminarSimulacao`$$
CREATE DEFINER=`root`@`%` PROCEDURE `SP_TerminarSimulacao` (IN `p_id_simulacao` INT)   BEGIN
UPDATE simulacao SET Estado = '2', DataHoraFim = CURRENT_TIMESTAMP WHERE IDSimulacao = p_id_simulacao;
END$$

DROP PROCEDURE IF EXISTS `SP_ValidarLogin`$$
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

DROP PROCEDURE IF EXISTS `SP_ValidarParametros`$$
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

DROP PROCEDURE IF EXISTS `SP_VisualizarDetalhes`$$
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

DROP PROCEDURE IF EXISTS `SP_VisualizarDetalhes_Historico`$$
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
-- Estrutura da tabela `corredor`
--

DROP TABLE IF EXISTS `corredor`;
CREATE TABLE IF NOT EXISTS `corredor` (
  `IDCorredor` int NOT NULL AUTO_INCREMENT,
  `Aberto` tinyint(1) NOT NULL,
  `IDSalaA` int NOT NULL,
  `IDSalaB` int NOT NULL,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`IDCorredor`),
  KEY `fk_corredor_simulacao` (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `corredor`
--
DROP TRIGGER IF EXISTS `trg_Manter_Fechado`;
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
-- Estrutura da tabela `historico_medicoespassagens`
--

DROP TABLE IF EXISTS `historico_medicoespassagens`;
CREATE TABLE IF NOT EXISTS `historico_medicoespassagens` (
  `IDMedicao` int NOT NULL,
  `Hora` timestamp NULL DEFAULT NULL,
  `SalaOrigem` int NOT NULL,
  `SalaDestino` int NOT NULL,
  `IDMarsami` int NOT NULL,
  `Status` int NOT NULL,
  `IDMongo` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`IDMedicao`,`IDSimulacao`),
  KEY `fk_passagens_simulacao` (`IDSimulacao`),
  KEY `fk_passagens_salaO` (`SalaOrigem`),
  KEY `fk_passagens_salaD` (`SalaDestino`),
  KEY `fk_passagens_marsami` (`IDMarsami`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `historico_ocupacaolabirinto`
--

DROP TABLE IF EXISTS `historico_ocupacaolabirinto`;
CREATE TABLE IF NOT EXISTS `historico_ocupacaolabirinto` (
  `NumeroMarsamisOdd` int NOT NULL,
  `NumeroMarsamisEven` int NOT NULL,
  `Sala` int NOT NULL,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`Sala`,`IDSimulacao`),
  KEY `fk_ocupacao_sala` (`Sala`),
  KEY `fk_ocupacao_simulacao` (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `historico_simulacao`
--

DROP TABLE IF EXISTS `historico_simulacao`;
CREATE TABLE IF NOT EXISTS `historico_simulacao` (
  `IDSimulacao` int NOT NULL,
  `Descricao` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Equipa` int NOT NULL,
  `DataHoraInicio` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataHoraFim` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Pontos` int DEFAULT NULL,
  `Criador` int NOT NULL DEFAULT '0',
  `TempMaxAlerta` decimal(6,2) DEFAULT NULL,
  `TempMinAlerta` decimal(6,2) DEFAULT NULL,
  `RuidoMaxAlerta` decimal(6,2) DEFAULT NULL,
  `SegundosIntervaloAlertas` int DEFAULT '60',
  `MargemToleranciaOutlier` decimal(6,2) DEFAULT NULL,
  `Periodicidade` int DEFAULT NULL,
  `Estado` enum('0','1','2') NOT NULL DEFAULT '0',
  PRIMARY KEY (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `marsami`
--

DROP TABLE IF EXISTS `marsami`;
CREATE TABLE IF NOT EXISTS `marsami` (
  `IDMarsami` int NOT NULL,
  `Cansado` tinyint(1) NOT NULL,
  `IDSala` int NOT NULL,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`IDMarsami`),
  KEY `fk_marsami_simulacao` (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `marsami`
--
DROP TRIGGER IF EXISTS `trg_Verificar_Cansados`;
DELIMITER $$
CREATE TRIGGER `trg_Verificar_Cansados` AFTER UPDATE ON `marsami` FOR EACH ROW BEGIN
    DECLARE v_nao_cansados INT DEFAULT 0;

    -- Só agimos se o Marsami acabou de ficar cansado nesta atualização
    IF NEW.Cansado = 1 AND OLD.Cansado = 0 THEN

        -- Contamos quantos Marsamis ainda NÃO estão cansados nesta simulação
        SELECT COUNT(*) INTO v_nao_cansados
        FROM marsami
        WHERE IDSimulacao = OLD.IDSimulacao AND Cansado = 0;

        -- Se não sobrar nenhum robô ativo, chamamos a SP para terminar a simulação!
        IF v_nao_cansados = 0 THEN
            CALL SP_TerminarSimulacao(OLD.IDSimulacao);
        END IF;

    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `medicoespassagens`
--

DROP TABLE IF EXISTS `medicoespassagens`;
CREATE TABLE IF NOT EXISTS `medicoespassagens` (
  `IDMedicao` int NOT NULL AUTO_INCREMENT,
  `IDSimulacao` int NOT NULL,
  `IDMarsami` int DEFAULT NULL,
  `SalaOrigem` int DEFAULT NULL,
  `SalaDestino` int DEFAULT NULL,
  `Status` varchar(50) DEFAULT NULL,
  `IDMongo` varchar(50) DEFAULT NULL,
  `DataMedicao` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`IDMedicao`),
  KEY `fk_passagens_simulacao_ref` (`IDSimulacao`),
  KEY `fk_passagens_marsami_ref` (`IDMarsami`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `mensagens`
--

DROP TABLE IF EXISTS `mensagens`;
CREATE TABLE IF NOT EXISTS `mensagens` (
  `ID` int NOT NULL AUTO_INCREMENT,
  `Hora` varchar(50) DEFAULT NULL,
  `Sensor` varchar(10) DEFAULT NULL,
  `Leitura` decimal(6,2) DEFAULT NULL,
  `TipoAlerta` varchar(50) DEFAULT NULL,
  `Msg` text,
  `HoraEscrita` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `fk_mensagens_simulacao` (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `ocupacaolabirinto`
--

DROP TABLE IF EXISTS `ocupacaolabirinto`;
CREATE TABLE IF NOT EXISTS `ocupacaolabirinto` (
  `NumeroMarsamisOdd` int NOT NULL,
  `NumeroMarsamisEven` int NOT NULL,
  `Sala` int NOT NULL,
  `IDSimulacao` int NOT NULL,
  PRIMARY KEY (`Sala`,`IDSimulacao`),
  KEY `fk_ocupacao_simulacao` (`IDSimulacao`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `simulacao`
--

DROP TABLE IF EXISTS `simulacao`;
CREATE TABLE IF NOT EXISTS `simulacao` (
  `IDSimulacao` int NOT NULL AUTO_INCREMENT,
  `Descricao` varchar(255) DEFAULT NULL,
  `Equipa` int NOT NULL,
  `DataHoraInicio` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `DataHoraFim` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Pontos` decimal(6,1) DEFAULT NULL,
  `Criador` int NOT NULL,
  `TempMaxAlerta` decimal(6,2) DEFAULT NULL,
  `TempMinAlerta` decimal(6,2) DEFAULT NULL,
  `RuidoMaxAlerta` decimal(6,2) DEFAULT NULL,
  `SegundosIntervaloAlertas` int DEFAULT '60',
  `Periodicidade` int DEFAULT NULL,
  `Estado` enum('0','1','2') NOT NULL DEFAULT '0',
  PRIMARY KEY (`IDSimulacao`),
  KEY `fk_simulacao_criador` (`Criador`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `som`
--

DROP TABLE IF EXISTS `som`;
CREATE TABLE IF NOT EXISTS `som` (
  `IDSom` int NOT NULL AUTO_INCREMENT,
  `Hora` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Som` decimal(6,2) NOT NULL,
  PRIMARY KEY (`IDSom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `temperatura`
--

DROP TABLE IF EXISTS `temperatura`;
CREATE TABLE IF NOT EXISTS `temperatura` (
  `IDTemperatura` int NOT NULL AUTO_INCREMENT,
  `Hora` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Temperatura` decimal(6,2) NOT NULL,
  PRIMARY KEY (`IDTemperatura`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estrutura da tabela `utilizador`
--

DROP TABLE IF EXISTS `utilizador`;
CREATE TABLE IF NOT EXISTS `utilizador` (
  `IDUtilizador` int NOT NULL AUTO_INCREMENT,
  `Nome` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `Telemovel` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `Tipo` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `Email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `DataNascimento` date DEFAULT NULL,
  `Equipa` int NOT NULL,
  PRIMARY KEY (`IDUtilizador`)
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Extraindo dados da tabela `utilizador`
--

INSERT INTO `utilizador` (`IDUtilizador`, `Nome`, `Telemovel`, `Tipo`, `Email`, `DataNascimento`, `Equipa`) VALUES
(1, 'Ana Maria Braga', NULL, '', 'ana@email.com', NULL, 0),
(2, 'Bruno Ramos', NULL, '', 'bruno@email.com', NULL, 0),
(3, 'Utilizador PHP 1', NULL, 'web', 'user1_php', NULL, 1),
(4, 'Utilizador PHP 2', NULL, 'web', 'user2_php', NULL, 2),
(7, 'ola', NULL, 'web', 'rrlfx@iscte.pt', NULL, 0),
(9, 'Maria Completa', '912345678', 'web', 'maria@teste.com', '1998-05-20', 0),
(10, 'Ricardo Tel', '933444555', 'web', 'ric@teste.com', NULL, 0),
(11, 'Joao Com Equipa', '912345678', 'web', 'joao.equipa@teste.com', '2000-01-01', 1),
(12, 'teste', '123', 'web', 'teste', '2020-11-11', 7),
(13, 'Novo Dev', NULL, 'web', 'dev@lab.com', NULL, 1),
(14, 'ola', '56566565', 'web', 'teste2@iscte.pt', '2020-12-12', 7),
(15, 'Chefe Supremo', '919999999', 'Admin', 'admin.master@lab.pt', '1980-05-20', 1),
(17, 'Chefe Supremo', '000000000', 'Admin', 'admin.grande@lab.pt', '1980-07-27', 1),
(18, 'Teste do Admin: Criar pela SP', NULL, 'Utilizador', 'UserFeitoPorAdim@lab.pt', NULL, 1),
(19, 'Nome Editado Com Sucesso', NULL, 'Utilizador', 'direto@lab.pt', NULL, 1),
(21, 'mudei', '037167819', 'Utilizador', 'jogador.teste@lab.pt', '2000-01-07', 2),
(24, 'Novo Admin Supremo', '999888777', 'Admin', 'admin2@lab.pt', '1990-01-01', 1),
(25, 'Robo Marsami', NULL, 'Migrador', 'robo.migrador2@lab.pt', NULL, 1),
(26, 'Tablet Sala 1', NULL, 'Monitor Android', 'monitor@lab.pt', NULL, 1),
(27, 'Tablet Sala 1', NULL, 'Monitor Android', 'monitor2@lab.pt', NULL, 1);

--
-- Restrições para despejos de tabelas
--

--
-- Limitadores para a tabela `corredor`
--
ALTER TABLE `corredor`
  ADD CONSTRAINT `fk_corredor_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `marsami`
--
ALTER TABLE `marsami`
  ADD CONSTRAINT `fk_marsami_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  ADD CONSTRAINT `fk_passagens_marsami_ref` FOREIGN KEY (`IDMarsami`) REFERENCES `marsami` (`IDMarsami`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_passagens_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `fk_mensagens_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
  ADD CONSTRAINT `fk_ocupacao_simulacao_ref` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `simulacao`
--
ALTER TABLE `simulacao`
  ADD CONSTRAINT `fk_simulacao_criador_ref` FOREIGN KEY (`Criador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE CASCADE ON UPDATE CASCADE;

DELIMITER $$
--
-- Eventos
--
DROP EVENT IF EXISTS `evt_Exportar_Historico_CSV`$$
CREATE DEFINER=`root`@`%` EVENT `evt_Exportar_Historico_CSV` ON SCHEDULE EVERY 1 MONTH STARTS '2026-06-01 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    -- Gerar o sufixo da data atual (Ex: '2026_06') para garantir que os ficheiros não se sobrepõem
    SET @data_atual = DATE_FORMAT(NOW(), '%Y_%m');

    -- =========================================================================
    -- PASSO A: EXPORTAR PARA CSV (Usando nomes de ficheiros dinâmicos)
    -- =========================================================================
    
    -- 1. Backup: Ocupação Labirinto
    SET @query1 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/historico_ocupacao_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_ocupacaolabirinto');
    PREPARE stmt1 FROM @query1;
    EXECUTE stmt1;
    DEALLOCATE PREPARE stmt1;

    -- 2. Backup: Medições Passagens
    SET @query2 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/historico_medicoes_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_medicoespassagens');
    PREPARE stmt2 FROM @query2;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;

    -- 3. Backup: Simulação
    SET @query3 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/historico_simulacao_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_simulacao');
    PREPARE stmt3 FROM @query3;
    EXECUTE stmt3;
    DEALLOCATE PREPARE stmt3;

    -- =========================================================================
    -- PASSO B: LIMPAR AS TABELAS DE HISTÓRICO APÓS O BACKUP
    -- =========================================================================
    
    TRUNCATE TABLE historico_ocupacaolabirinto;
    TRUNCATE TABLE historico_medicoespassagens;
    TRUNCATE TABLE historico_simulacao;

END$$

DELIMITER ;
SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
