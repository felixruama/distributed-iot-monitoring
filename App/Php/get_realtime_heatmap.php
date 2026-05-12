<?php
include "db_config.php";

// Query que conta passagens por sala
$query = "SELECT SalaDestino as sala, COUNT(*) as intensidade
          FROM medicoespassagens
          GROUP BY SalaDestino";

$result = mysqli_query($conn, $query);
$data = array();

while ($row = mysqli_fetch_assoc($result)) {
    $data[] = array(
        'sala' => (int)$row['sala'],
        'intensidade' => (int)$row['intensidade']
    );
}

header('Content-Type: application/json');
echo json_encode(array("success" => true, "data" => $data));
mysqli_close($conn);
?>