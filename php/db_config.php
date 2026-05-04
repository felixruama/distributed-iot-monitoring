<?php
$host = 'mysql'; // Nome do serviço no docker-compose
$db   = 'labirinto_DB';
$user = 'root'; // Password definida no seu docker-compose
$pass = 'root';
$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) { die(json_encode(["success" => false, "message" => "Erro: " . $conn->connect_error])); }
?>