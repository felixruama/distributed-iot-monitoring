<?php
include "db_config.php"; // Garante que esteuu ficheiro tem a tua ligação à BD

$user_id = $_GET['user_id'];
$query = "CALL SP_GetResumoFinal()";

if (mysqli_multi_query($conn, $query)) {
    $results = [];
    do {
        if ($result = mysqli_store_result($conn)) {
            $results[] = mysqli_fetch_all($result, MYSQLI_ASSOC);
            mysqli_free_result($result);
        }
    } while (mysqli_next_result($conn));

    // Organizar a resposta
    echo json_encode([
        "success" => true,
        "detalhes" => $results[0][0],   // Informações gerais
        "ativo" => $results[1][0],     // Robô Mais Ativo
        "explorador" => $results[2][0], // Explorador
        "hotspot" => $results[3][0]     // Sala mais visitada
    ]);
}
mysqli_close($conn);
?>