<?php
require_once('db_connection.php');

class SPHandler {
    private $pdo;

    public function __construct($pdo) {
        $this->pdo = $pdo;
    }

    /**
     * Executa uma SP que devolve resultados (SELECT)
     */
    public function getData($spName, $params = []) {
        try {
            $placeholders = count($params) > 0 ? str_repeat('?,', count($params) - 1) . '?' : '';
            $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
            $stmt->execute($params);
            return $stmt->fetchAll();
        } catch (PDOException $e) {
            die("Erro na SP $spName: " . $e->getMessage());
        }
    }

    /**
     * Executa uma SP de ação (INSERT, UPDATE, DELETE)
     */
    public function execute($spName, $params = []) {
        try {
            $placeholders = count($params) > 0 ? str_repeat('?,', count($params) - 1) . '?' : '';
            $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
            return $stmt->execute($params);
        } catch (PDOException $e) {
            die("Erro ao executar $spName: " . $e->getMessage());
        }
    }
}

// Criamos a instância global para usar nos outros ficheiros
$spManager = new SPHandler($pdo);
?>