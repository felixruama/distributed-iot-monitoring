<?php
class SPManager {
    private $pdo;

    public function __construct() {
        // Ajusta a password 'root' caso seja diferente no teu PC/Docker
        try {
            $this->pdo = new PDO("mysql:host=mysql;dbname=labirinto_DB;charset=utf8mb4", "root", "root");
            $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch (PDOException $e) {
            die("Erro de ligação à BD: " . $e->getMessage());
        }
    }

    // Função para executar SPs que devolvem dados (Ex: VisualizarDetalhes, ValidarLogin)
    public function getData($spName, $params = []) {
        $placeholders = empty($params) ? '' : implode(',', array_fill(0, count($params), '?'));
        $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // Função para executar SPs que apenas inserem/atualizam dados (Ex: ValidarParametros)
    public function executeAction($spName, $params = []) {
        $placeholders = empty($params) ? '' : implode(',', array_fill(0, count($params), '?'));
        $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
        $stmt->execute($params);
        return $stmt; // Para podermos ver as mensagens de SUCESSO/ERRO que o MySQL devolve
    }
}

$spManager = new SPManager();
?>