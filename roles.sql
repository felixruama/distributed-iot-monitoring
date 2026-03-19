-- ==========================================
-- 1. CRIAR OS UTILIZADORES
-- ==========================================
CREATE USER 'admin_user'@'%' IDENTIFIED BY 'SenhaAdmin123';
CREATE USER 'utilizador_php'@'%' IDENTIFIED BY 'SenhaPhp123';
CREATE USER 'monitor_android'@'%' IDENTIFIED BY 'SenhaAndroid123';
CREATE USER 'migrador_python'@'%' IDENTIFIED BY 'SenhaPython123';

-- ==========================================
-- 2. PERMISSÕES: MIGRADOR DO MONGODB (Python)
-- ==========================================
-- Ele só escreve o que vem dos sensores e lê flags de simulação/outliers
GRANT UPDATE ON labirinto_db.ocupacaoLabirinto TO 'migrador_python'@'%';
GRANT INSERT ON labirinto_db.som TO 'migrador_python'@'%';
GRANT INSERT ON labirinto_db.temperatura TO 'migrador_python'@'%';
GRANT INSERT ON labirinto_db.medicoEspassagens TO 'migrador_python'@'%'; -- (Assumo que seja medico/passagens)
GRANT INSERT, SELECT ON labirinto_db.mensagens TO 'migrador_python'@'%'; -- I/L para outliers
GRANT SELECT, UPDATE ON labirinto_db.marsami TO 'migrador_python'@'%';
GRANT SELECT ON labirinto_db.simulacao TO 'migrador_python'@'%'; -- L para ver a flag

-- ==========================================
-- 3. PERMISSÕES: MONITOR (Android)
-- ==========================================
-- O Android só pode ver! (Só tem "L")
GRANT SELECT ON labirinto_db.ocupacaoLabirinto TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.som TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.temperatura TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.corredor TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.sala TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.marsami TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.medicoEspassagens TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.mensagens TO 'monitor_android'@'%';
GRANT SELECT ON labirinto_db.simulacao TO 'monitor_android'@'%';
-- Nota: Não tem permissão na tabela 'utilizador' nem na SP1, tal como na matriz ("-").

-- ==========================================
-- 4. PERMISSÕES: UTILIZADOR / JOGADOR (PHP)
-- ==========================================
GRANT SELECT ON labirinto_db.ocupacaoLabirinto TO 'utilizador_php'@'%';
GRANT SELECT ON labirinto_db.som TO 'utilizador_php'@'%';
GRANT SELECT ON labirinto_db.temperatura TO 'utilizador_php'@'%';
GRANT SELECT, UPDATE ON labirinto_db.corredor TO 'utilizador_php'@'%'; -- Pode abrir/fechar (U)
GRANT SELECT ON labirinto_db.sala TO 'utilizador_php'@'%';
GRANT SELECT, INSERT, UPDATE ON labirinto_db.marsami TO 'utilizador_php'@'%';
GRANT SELECT ON labirinto_db.medicoEspassagens TO 'utilizador_php'@'%';
GRANT SELECT ON labirinto_db.mensagens TO 'utilizador_php'@'%';
GRANT SELECT, UPDATE ON labirinto_db.utilizador TO 'utilizador_php'@'%'; -- Para mudar nome (U)
GRANT SELECT, INSERT, UPDATE ON labirinto_db.simulacao TO 'utilizador_php'@'%';
GRANT EXECUTE ON PROCEDURE labirinto_db.sp_EditarNome TO 'utilizador_php'@'%'; -- Pode executar a SP1 (X)

-- ==========================================
-- 5. PERMISSÕES: ADMINISTRADOR
-- ==========================================
GRANT ALL PRIVILEGES ON labirinto_db.ocupacaoLabirinto TO 'admin_user'@'%';
GRANT SELECT, DELETE ON labirinto_db.som TO 'admin_user'@'%';
GRANT SELECT, DELETE ON labirinto_db.temperatura TO 'admin_user'@'%';
GRANT ALL PRIVILEGES ON labirinto_db.corredor TO 'admin_user'@'%';
GRANT ALL PRIVILEGES ON labirinto_db.sala TO 'admin_user'@'%';
GRANT ALL PRIVILEGES ON labirinto_db.marsami TO 'admin_user'@'%';
GRANT SELECT, DELETE ON labirinto_db.medicoEspassagens TO 'admin_user'@'%';
GRANT SELECT, DELETE ON labirinto_db.mensagens TO 'admin_user'@'%';
GRANT ALL PRIVILEGES ON labirinto_db.utilizador TO 'admin_user'@'%';
GRANT ALL PRIVILEGES ON labirinto_db.simulacao TO 'admin_user'@'%';
GRANT EXECUTE ON PROCEDURE labirinto_db.sp_EditarNome TO 'admin_user'@'%';

FLUSH PRIVILEGES;