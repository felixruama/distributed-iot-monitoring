-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql
-- Generation Time: Apr 28, 2026 at 01:33 PM
-- Server version: 8.0.45
-- PHP Version: 8.3.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `labirinto_db_final`
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

CREATE DEFINER=`root`@`%` PROCEDURE `SP_CriarSimulacao` (IN `p_IDUtilizador` INT, IN `p_Descricao` TEXT)   BEGIN
    DECLARE v_equipa INT DEFAULT 0;
    SELECT Equipa INTO v_equipa FROM utilizador WHERE IDUtilizador = p_IDUtilizador;
    IF v_equipa IS NULL THEN SET v_equipa = 0; END IF;

    INSERT INTO simulacao (Descricao, Equipa, Criador, SimulacaoIniciada, Pontos, Estado)
    VALUES (p_Descricao, v_equipa, p_IDUtilizador, 0, 0, '0');

    SELECT LAST_INSERT_ID() AS IDSimulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_CriarUtilizador` (IN `p_Nome` VARCHAR(100), IN `p_Email` VARCHAR(50), IN `p_Password` VARCHAR(255), IN `p_Tipo` VARCHAR(3))   BEGIN
    IF EXISTS (SELECT 1 FROM utilizador WHERE Email = p_Email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erro: Email ja registado.';
    ELSE
        -- permite null! confirmar
        INSERT INTO utilizador (Nome, Telemovel, Tipo, Password, Email, DataNascimento, Equipa)
        VALUES (p_Nome, NULL, p_Tipo, p_Password, p_Email, NULL, 0);
        
        SELECT LAST_INSERT_ID() AS IDUtilizador;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_EditarPerfil` (IN `p_id_utilizador` INT, IN `p_nome` VARCHAR(100), IN `p_telemovel` VARCHAR(12), IN `p_email` VARCHAR(50), IN `p_datanascimento` DATE, IN `p_equipa` INT, IN `p_password` VARCHAR(255))   BEGIN
    DECLARE v_email_da_conta VARCHAR(50);
    
    -- 1. Procurar o email da conta que se quer editar
    SELECT Email INTO v_email_da_conta FROM utilizador WHERE IDUtilizador = p_id_utilizador;

    -- 2. A TRANCA DE SEGURANÇA
    IF USER() NOT LIKE CONCAT(v_email_da_conta, '@%') AND USER() NOT LIKE 'root@%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acesso Negado: Não tem permissão para editar o perfil de outro utilizador.';
    ELSE
        -- 3. UPDATE COM PROTEÇÃO DE PASSWORD
        UPDATE utilizador
        SET 
            Nome = CASE WHEN p_nome IS NULL OR p_nome = '' THEN Nome ELSE p_nome END,
            Email = CASE WHEN p_email IS NULL OR p_email = '' THEN Email ELSE p_email END,
            Equipa = CASE WHEN p_equipa IS NULL OR p_equipa <= 0 THEN Equipa ELSE p_equipa END,
            
            -- LÓGICA DA PASSWORD: Se vier nula ou vazia, mantém a antiga!
            Password = CASE WHEN p_password IS NULL OR p_password = '' THEN Password ELSE p_password END,
            
            Telemovel = CASE WHEN p_telemovel IS NULL THEN Telemovel WHEN p_telemovel = '' THEN NULL ELSE p_telemovel END,
            
            -- Voltamos à data válida para evitar o bloqueio do motor MySQL
            DataNascimento = CASE WHEN p_datanascimento IS NULL THEN DataNascimento WHEN p_datanascimento = '1000-01-01' THEN NULL ELSE p_datanascimento END
        WHERE IDUtilizador = p_id_utilizador;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_EditarPerfilDinamico` (IN `p_id` INT, IN `p_dados_json` JSON)   BEGIN
    DECLARE v_email VARCHAR(50);

    -- 1. Obter o email correspondente ao ID para a verificação de segurança
    SELECT Email INTO v_email
    FROM utilizador
    WHERE IDUtilizador = p_id;

    -- 2. Validações Iniciais
    IF v_email IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Utilizador nao encontrado.';
        
    -- Mantive a regra de segurança original do MySQL USER()
    ELSEIF USER() NOT LIKE CONCAT(v_email, '@%') COLLATE utf8mb4_general_ci THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro de Seguranca: Nao tens permissao para editar o perfil de outra conta!';
        
    -- 3. Atualização Universal Dinâmica
    ELSE
        -- O MySQL tenta extrair a chave do JSON. 
        -- Se o PHP não a enviou, o JSON_EXTRACT devolve NULL.
        -- A função COALESCE deteta o NULL e mantém o valor antigo que já estava na tabela.
        UPDATE utilizador 
        SET 
            Nome = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_dados_json, '$.Nome')), Nome),
            Password = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_dados_json, '$.Password')), Password),
            Telemovel = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_dados_json, '$.Telemovel')), Telemovel),
            DataNascimento = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_dados_json, '$.DataNascimento')), DataNascimento)
        WHERE IDUtilizador = p_id;
        
        -- Validação pós-update (por exemplo, se o nome enviado no JSON for muito curto)
        IF JSON_EXTRACT(p_dados_json, '$.Nome') IS NOT NULL AND LENGTH(TRIM(Nome)) < 3 THEN
             -- Se a regra for violada, fazemos ROLLBACK implícito ao disparar o sinal
             SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro de Validacao: O nome deve ter pelo menos 3 caracteres.';
        END IF;

        IF ROW_COUNT() = 0 THEN
            SELECT 'AVISO: Nenhuma alteracao foi detetada nos dados.' AS Resultado;
        ELSE
            SELECT 'SUCESSO: Perfil atualizado de forma dinâmica com sucesso!' AS Resultado;
        END IF;
        
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

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ObterHistorico` (IN `p_IDUtilizador` INT)   BEGIN
    SELECT * FROM historico_simulacao WHERE Criador = p_IDUtilizador;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_RegistarAlerta` (IN `p_id_simulacao` INT, IN `p_tipo_sensor` VARCHAR(10), IN `p_valor` DECIMAL(6,2), IN `p_sala` INT)   BEGIN
    DECLARE v_intervalo INT DEFAULT 60;
    DECLARE v_ultimo_valor DECIMAL(6,2) DEFAULT NULL;
    DECLARE v_ultima_hora TIMESTAMP DEFAULT NULL;
    DECLARE v_segundos_passados INT DEFAULT 0;

    SELECT SegundosIntervaloAlertas INTO v_intervalo
    FROM simulacao WHERE IDSimulacao = p_id_simulacao;

    SELECT m.Leitura, m.HoraEscrita INTO v_ultimo_valor, v_ultima_hora
    FROM mensagens m
    JOIN sala s ON m.Sala = s.IDSala
    WHERE s.IDSimulacao = p_id_simulacao AND m.Sensor = p_tipo_sensor AND m.Sala = p_sala
    ORDER BY m.HoraEscrita DESC
    LIMIT 1;

    IF v_ultima_hora IS NOT NULL THEN
        SET v_segundos_passados = TIMESTAMPDIFF(SECOND, v_ultima_hora, NOW());
    END IF;

    IF v_ultima_hora IS NOT NULL AND v_segundos_passados < v_intervalo AND v_ultimo_valor = p_valor THEN
        SELECT 'Alerta suprimido pelo mecanismo anti-spam.' AS Resultado;
    ELSE
        INSERT INTO mensagens (Hora, Sala, Sensor, Leitura, TipoAlerta, Msg, HoraEscrita)
        VALUES (NOW(), p_sala, p_tipo_sensor, p_valor,
                CONCAT('Alerta ', p_tipo_sensor),
                CONCAT('Valor critico detectado: ', p_valor),
                NOW());
        SELECT 'Alerta registado com sucesso.' AS Resultado;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_RegistarPassagem` (IN `p_id_simulacao` INT, IN `p_id_marsami` INT, IN `p_origem` INT, IN `p_destino` INT, IN `p_status` INT, IN `p_idmongo` VARCHAR(24) CHARSET utf8mb4 COLLATE utf8mb4_general_ci)   BEGIN
    DECLARE v_parity INT;
    SET v_parity = p_id_marsami % 2;

    -- Record the passage
    INSERT INTO medicoespassagens (Hora, SalaOrigem, SalaDestino, IDMarsami, Status, IDSimulacao, IDMongo)
    VALUES (NOW(), p_origem, p_destino, p_id_marsami, p_status, p_id_simulacao, p_idmongo);

    -- Update origin room count
    IF v_parity = 1 THEN
        UPDATE ocupacaolabirinto 
        SET NumeroMarsamisOdd = GREATEST(NumeroMarsamisOdd - 1, 0)
        WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
    ELSE
        UPDATE ocupacaolabirinto 
        SET NumeroMarsamisEven = GREATEST(NumeroMarsamisEven - 1, 0)
        WHERE Sala = p_origem AND IDSimulacao = p_id_simulacao;
    END IF;

    -- Update destination room count
    IF v_parity = 1 THEN
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao)
        VALUES (1, 0, p_destino, p_id_simulacao)
        ON DUPLICATE KEY UPDATE NumeroMarsamisOdd = NumeroMarsamisOdd + 1;
    ELSE
        INSERT INTO ocupacaolabirinto (NumeroMarsamisOdd, NumeroMarsamisEven, Sala, IDSimulacao)
        VALUES (0, 1, p_destino, p_id_simulacao)
        ON DUPLICATE KEY UPDATE NumeroMarsamisEven = NumeroMarsamisEven + 1;
    END IF;

    -- Update marsami location
    UPDATE marsami SET IDSala = p_destino 
    WHERE IDMarsami = p_id_marsami AND IDSimulacao = p_id_simulacao;

    -- If status = 2 (cansado), mark marsami as tired
    IF p_status = 2 THEN
        UPDATE marsami SET Cansado = 1 
        WHERE IDMarsami = p_id_marsami AND IDSimulacao = p_id_simulacao;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_TerminarSimulacao` (IN `p_id_simulacao` INT)   BEGIN
    UPDATE simulacao SET Estado = '2', DataHoraFim = CURRENT_TIMESTAMP WHERE IDSimulacao = p_id_simulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ValidarLogin` (IN `p_Email` VARCHAR(50) CHARSET utf8mb4 COLLATE utf8mb4_general_ci, IN `p_Password` VARCHAR(255) CHARSET utf8mb4 COLLATE utf8mb4_general_ci)   BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_tipo VARCHAR(3) DEFAULT NULL;

    SELECT IDUtilizador, Tipo INTO v_id, v_tipo
    FROM utilizador
    WHERE Email = p_Email AND Password = p_Password;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erro: Credenciais invalidas.';
    ELSE
        SELECT v_id AS IDUtilizador, v_tipo AS Tipo;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_ValidarParametros` (IN `p_IDSimulacao` INT, IN `p_TempMin` DECIMAL(6,2), IN `p_TempMax` DECIMAL(6,2), IN `p_RuidoMax` DECIMAL(6,2), IN `p_Periodicidade` INT, IN `p_DeltaOutlier` DECIMAL(6,2), IN `p_intervaloAlertas` INT)   BEGIN
    DECLARE v_estado ENUM('0','1','2');
    SELECT Estado INTO v_estado FROM simulacao WHERE IDSimulacao = p_IDSimulacao;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Simulacao nao encontrada.';
    ELSEIF v_estado != '0' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: So e possivel editar parametros de simulacoes no estado Criada.';
    ELSEIF p_TempMin >= p_TempMax THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Temperatura minima deve ser inferior a temperatura maxima.';
    ELSEIF p_Periodicidade < 0 OR p_intervaloAlertas < 0 OR p_DeltaOutlier < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Parametros numericos devem ser nao negativos.';
    ELSE
        UPDATE simulacao SET TempMinAlerta = p_TempMin, TempMaxAlerta = p_TempMax, RuidoMaxAlerta = p_RuidoMax,
            Periodicidade = p_Periodicidade, MargemToleranciaOutlier = p_DeltaOutlier, SegundosIntervaloAlertas = p_intervaloAlertas
        WHERE IDSimulacao = p_IDSimulacao;
        SELECT 'SUCESSO: Parametros atualizados com sucesso!' AS Resultado;
    END IF;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_VerificarGatilho` (IN `p_id_simulacao` INT, IN `p_id_sala` INT, OUT `p_autorizado` INT)   BEGIN
    DECLARE v_estado ENUM('0','1','2');
    DECLARE v_gatilhos INT DEFAULT 0;

    START TRANSACTION;
    SELECT Estado INTO v_estado FROM simulacao WHERE IDSimulacao = p_id_simulacao FOR UPDATE;
    SELECT nGatilhos INTO v_gatilhos FROM sala WHERE IDSala = p_id_sala AND IDSimulacao = p_id_simulacao FOR UPDATE;

    IF v_estado != '1' OR IFNULL(v_gatilhos, 0) >= 3 THEN
        SET p_autorizado = 0;
    ELSE
        UPDATE sala SET nGatilhos = nGatilhos + 1 WHERE IDSala = p_id_sala AND IDSimulacao = p_id_simulacao;
        SET p_autorizado = 1;
    END IF;
    COMMIT;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_VisualizarDetalhes` (IN `p_IDSimulacao` INT)   BEGIN
    SELECT * FROM simulacao WHERE IDSimulacao = p_IDSimulacao;
END$$

CREATE DEFINER=`root`@`%` PROCEDURE `SP_VisualizarDetalhes_Historico` (IN `p_IDSimulacao` INT)   BEGIN
    SELECT * FROM historico_simulacao WHERE IDSimulacao = p_IDSimulacao;
    SELECT * FROM historico_ocupacaolabirinto WHERE IDSimulacao = p_IDSimulacao;
    SELECT * FROM historico_medicoespassagens WHERE IDSimulacao = p_IDSimulacao;
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
  `IDMongo` varchar(24) COLLATE utf8mb4_general_ci DEFAULT NULL,
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

    IF NEW.Cansado = 1 THEN
        SELECT COUNT(*) INTO v_nao_cansados
        FROM marsami
        WHERE IDSimulacao = OLD.IDSimulacao AND Cansado = 0;

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
  `Hora` timestamp NULL DEFAULT NULL,
  `SalaOrigem` int NOT NULL,
  `SalaDestino` int NOT NULL,
  `IDMarsami` int NOT NULL,
  `Status` int NOT NULL,
  `IDMongo` varchar(24) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mensagens`
--

CREATE TABLE `mensagens` (
  `ID` int NOT NULL,
  `Hora` timestamp NULL DEFAULT NULL,
  `Sala` int NOT NULL,
  `Sensor` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Leitura` decimal(6,2) NOT NULL,
  `TipoAlerta` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Msg` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `HoraEscrita` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
-- Table structure for table `sala`
--

CREATE TABLE `sala` (
  `IDSala` int NOT NULL,
  `nGatilhos` int NOT NULL,
  `IDSimulacao` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `simulacao`
--

CREATE TABLE `simulacao` (
  `IDSimulacao` int NOT NULL,
  `Descricao` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
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
  `MargemToleranciaOutlier` decimal(6,2) DEFAULT NULL,
  `Periodicidade` int DEFAULT NULL,
  `Estado` enum('0','1','2') NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Triggers `simulacao`
--
DELIMITER $$
CREATE TRIGGER `trg_Arquivar_Simulacao` AFTER UPDATE ON `simulacao` FOR EACH ROW BEGIN
    -- 'Terminada' agora é '2'
    IF NEW.Estado = '2' AND OLD.Estado != '2' THEN
        INSERT INTO historico_simulacao SELECT * FROM simulacao WHERE IDSimulacao = OLD.IDSimulacao;
        INSERT INTO historico_ocupacaolabirinto SELECT * FROM ocupacaolabirinto WHERE IDSimulacao = OLD.IDSimulacao;
        INSERT INTO historico_medicoespassagens SELECT * FROM medicoespassagens WHERE IDSimulacao = OLD.IDSimulacao;

        DELETE FROM medicoespassagens WHERE IDSimulacao = OLD.IDSimulacao;
        
        -- Apagar mensagens usando um JOIN com a tabela sala
        DELETE m FROM mensagens m JOIN sala s ON m.Sala = s.IDSala WHERE s.IDSimulacao = OLD.IDSimulacao;
        
        -- (As tabelas som e temperatura foram removidas deste trigger porque perderam a relação)

        DELETE FROM marsami WHERE IDSimulacao = OLD.IDSimulacao;
        DELETE FROM corredor WHERE IDSimulacao = OLD.IDSimulacao;
        DELETE FROM ocupacaolabirinto WHERE IDSimulacao = OLD.IDSimulacao;
        DELETE FROM sala WHERE IDSimulacao = OLD.IDSimulacao;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `som`
--

CREATE TABLE `som` (
  `IDSom` int NOT NULL,
  `Hora` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Som` decimal(6,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `temperatura`
--

CREATE TABLE `temperatura` (
  `IDTemperatura` int NOT NULL,
  `Hora` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Temperatura` decimal(6,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `utilizador`
--

CREATE TABLE `utilizador` (
  `IDUtilizador` int NOT NULL,
  `Password` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `Nome` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Telemovel` varchar(12) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `Tipo` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `Email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `DataNascimento` date DEFAULT NULL,
  `Equipa` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `utilizador`
--

INSERT INTO `utilizador` (`IDUtilizador`, `Password`, `Nome`, `Telemovel`, `Tipo`, `Email`, `DataNascimento`, `Equipa`) VALUES
(1, '', 'Ana Mariaa', NULL, '', 'ana@email.com', NULL, 0),
(2, '', 'Bruno Ramos', NULL, '', 'bruno@email.com', NULL, 0),
(3, '', 'Utilizador PHP 1', NULL, 'web', 'user1_php', NULL, 1),
(4, '', 'Utilizador PHP 2', NULL, 'web', 'user2_php', NULL, 2),
(5, '', 'User PHP', NULL, 'adm', 'user_php', NULL, 0);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `corredor`
--
ALTER TABLE `corredor`
  ADD PRIMARY KEY (`IDCorredor`),
  ADD KEY `fk_corredor_simulacao` (`IDSimulacao`),
  ADD KEY `fk_corredor_salaB` (`IDSalaB`),
  ADD KEY `fk_corredor_salaA` (`IDSalaA`);

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
  ADD KEY `fk_marsami_simulacao` (`IDSimulacao`),
  ADD KEY `fk_marsami_sala` (`IDSala`);

--
-- Indexes for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  ADD PRIMARY KEY (`IDMedicao`),
  ADD KEY `fk_passagens_simulacao` (`IDSimulacao`),
  ADD KEY `fk_passagens_salaO` (`SalaOrigem`),
  ADD KEY `fk_passagens_salaD` (`SalaDestino`),
  ADD KEY `fk_passagens_marsami` (`IDMarsami`);

--
-- Indexes for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `fk_mensagens_sala` (`Sala`);

--
-- Indexes for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
  ADD PRIMARY KEY (`Sala`,`IDSimulacao`),
  ADD KEY `fk_ocupacao_sala` (`Sala`),
  ADD KEY `fk_ocupacao_simulacao` (`IDSimulacao`);

--
-- Indexes for table `sala`
--
ALTER TABLE `sala`
  ADD PRIMARY KEY (`IDSala`),
  ADD KEY `fk_sala_simulacao` (`IDSimulacao`);

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
  ADD PRIMARY KEY (`IDUtilizador`),
  ADD UNIQUE KEY `Email` (`Email`);

--
-- AUTO_INCREMENT for dumped tables
--

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
  MODIFY `IDSimulacao` int NOT NULL AUTO_INCREMENT;

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
  MODIFY `IDUtilizador` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `corredor`
--
ALTER TABLE `corredor`
  ADD CONSTRAINT `fk_corredor_salaA` FOREIGN KEY (`IDSalaA`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_corredor_salaB` FOREIGN KEY (`IDSalaB`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_corredor_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `marsami`
--
ALTER TABLE `marsami`
  ADD CONSTRAINT `fk_marsami_sala` FOREIGN KEY (`IDSala`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_marsami_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  ADD CONSTRAINT `fk_passagens_marsami` FOREIGN KEY (`IDMarsami`) REFERENCES `marsami` (`IDMarsami`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_passagens_salaD` FOREIGN KEY (`SalaDestino`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_passagens_salaO` FOREIGN KEY (`SalaOrigem`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_passagens_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `fk_mensagens_sala` FOREIGN KEY (`Sala`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
  ADD CONSTRAINT `fk_ocupacao_sala` FOREIGN KEY (`Sala`) REFERENCES `sala` (`IDSala`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  ADD CONSTRAINT `fk_ocupacao_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `sala`
--
ALTER TABLE `sala`
  ADD CONSTRAINT `fk_sala_simulacao` FOREIGN KEY (`IDSimulacao`) REFERENCES `simulacao` (`IDSimulacao`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `simulacao`
--
ALTER TABLE `simulacao`
  ADD CONSTRAINT `fk_simulacao_criador` FOREIGN KEY (`Criador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE RESTRICT ON UPDATE CASCADE;

DELIMITER $$
--
-- Events
--
CREATE DEFINER=`root`@`%` EVENT `evt_Exportar_Historico_CSV` ON SCHEDULE EVERY 1 MONTH STARTS '2026-05-01 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    -- Utilização de Dynamic SQL para inserir a data no nome do ficheiro e evitar sobreposição
    SET @data_atual = DATE_FORMAT(NOW(), '%Y%m%d_%H%M%S');
    
    SET @sql1 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/hist_simulacao_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' OPTIONALLY ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_simulacao');
    PREPARE stmt1 FROM @sql1; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

    SET @sql2 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/hist_ocupacao_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' OPTIONALLY ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_ocupacaolabirinto');
    PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

    SET @sql3 = CONCAT('SELECT * INTO OUTFILE ''/var/lib/mysql-files/hist_passagens_', @data_atual, '.csv'' FIELDS TERMINATED BY '','' OPTIONALLY ENCLOSED BY ''"'' LINES TERMINATED BY ''\n'' FROM historico_medicoespassagens');
    PREPARE stmt3 FROM @sql3; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;

    -- Limpar as tabelas de histórico após a exportação
    DELETE FROM historico_medicoespassagens;
    DELETE FROM historico_ocupacaolabirinto;
    DELETE FROM historico_simulacao;
END$$

CREATE DEFINER=`root`@`%` EVENT `evt_ProcessarTerminacoes` ON SCHEDULE EVERY 10 SECOND STARTS '2026-04-28 11:45:43' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    DECLARE v_sim_id INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE cur CURSOR FOR SELECT IDSimulacao FROM fila_terminacao;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_sim_id;
        IF done THEN LEAVE read_loop; END IF;
        CALL SP_TerminarSimulacao(v_sim_id);
        DELETE FROM fila_terminacao WHERE IDSimulacao = v_sim_id;
    END LOOP;
    CLOSE cur;
END$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
