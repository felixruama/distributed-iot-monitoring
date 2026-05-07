<?php
include 'db_config.php';

// Vai buscar o RuidoMaxAlerta da simulação mais recente[cite: 1, 8]
$sql = "SELECT RuidoMaxAlerta FROM simulacao WHERE Estado = '1' LIMIT 1";
$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    // O Android espera um JSON com a chave "maximo" dentro de "data"[cite: 8]
    echo json_encode(["success" => true, "data" => ["maximo" => (float)$row['RuidoMaxAlerta']]]);
} else {
    // Se não houver simulação, devolve um valor padrão (ex: 80)
    echo json_encode(["success" => true, "data" => ["maximo" => 80.0]]);
}
?>