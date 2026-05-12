<?php
// GARANTE QUE NÃO HÁ ESPAÇOS ANTES DO <?php

class SPManager {
    private $pdo;

    public function __construct() {
        try {
            $this->pdo = new PDO("mysql:host=mysql;dbname=labirinto_DB;charset=utf8mb4", "root", "root");
            $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch (PDOException $e) {
            die("Erro de ligação à BD: " . $e->getMessage());
        }
    }

    public function getData($spName, $params = []) {
        $placeholders = empty($params) ? '' : implode(',', array_fill(0, count($params), '?'));
        $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function executeAction($spName, $params = []) {
        $placeholders = empty($params) ? '' : implode(',', array_fill(0, count($params), '?'));
        $stmt = $this->pdo->prepare("CALL $spName($placeholders)");
        $stmt->execute($params);
        return $stmt;
    }
}

// Cria a instância para ser usada noutros ficheiros
$spManager = new SPManager();