<?php
include "db_config.php";

// Contamos quantas vezes cada sala foi destino de um Marsami na simulação atual
$query = "SELECT SalaDestino as Sala, COUNT(*) as Intensidade
          FROM medicoespassagens
          GROUP BY SalaDestino";

$result = mysqli_query($conn, $query);
$heatmap = array();

while ($row = mysqli_fetch_assoc($result)) {
    $heatmap[] = array(
        'sala' => (int)$row['Sala'],
        'intensidade' => (int)$row['Intensidade']
    );
}

header('Content-Type: application/json');
echo json_encode($heatmap);
mysqli_close($conn);
?>