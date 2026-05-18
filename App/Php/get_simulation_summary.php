<?php
// Silencia os warnings no output para não estragar o JSON no Android
error_reporting(0);

include "db_config.php";

// Evitar o warning do $_GET['user_id'] caso o Android não o envie
$user_id = $_GET['user_id'] ?? null;

$query = "CALL SP_GetResumoFinal()";

if (mysqli_multi_query($conn, $query)) {
    $results = [];
    do {
        if ($result = mysqli_store_result($conn)) {
            $results[] = mysqli_fetch_all($result, MYSQLI_ASSOC);
            mysqli_free_result($result);
        }
    } while (mysqli_more_results($conn) && mysqli_next_result($conn));

    // O operador "?? null" protege contra os Warnings caso a SP não devolva resultados
    // (ex: os marsamis não se mexeram)
    echo json_encode([
        "success" => true,
        "detalhes" => $results[0][0] ?? null,   // Informações gerais
        "ativo" => $results[1][0] ?? null,      // Robô Mais Ativo
        "explorador" => $results[2][0] ?? null, // Explorador
        "hotspot" => $results[3][0] ?? null     // Sala mais visitada
    ]);
} else {
    echo json_encode([
        "success" => false,
        "error" => "Erro ao executar Stored Procedure: " . mysqli_error($conn)
    ]);
}
mysqli_close($conn);
?>