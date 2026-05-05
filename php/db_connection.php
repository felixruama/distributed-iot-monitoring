<?php
$host = 'mysql'; // No teu dump o host aparece como mysql
$db   = 'labirinto_DB';
$user = 'root';
$pass = 'root_password'; // Ajusta conforme o teu ambiente (ex: vazio ou 'root')
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
     $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
     die("Erro de ligação: " . $e->getMessage());
}
?>