<?php
header('Content-Type: application/json');
include 'db_config.php';

$sql = "SELECT IDSom as idsom, Som as som 
        FROM som 
        ORDER BY Hora DESC LIMIT 20";

$result = $conn->query($sql);
$lista = [];

if ($result && $result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $lista[] = [
            "idsom" => (int)$row['idsom'],
            "som" => (float)$row['som']
        ];
    }
}

echo json_encode(["success" => true, "data" => array_reverse($lista)]);
?>