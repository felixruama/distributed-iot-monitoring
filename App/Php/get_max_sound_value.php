<?php
error_reporting(0);
header('Content-Type: application/json');

include 'db_config.php';

// 1. LIMITES LOCAIS (ALERTA)
$alerta_max = 80.0;
// CORREÇÃO: Simulação mais recente
$sql_local = "SELECT RuidoMaxAlerta FROM simulacao ORDER BY IDSimulacao DESC LIMIT 1";
$result_local = $conn->query($sql_local);

if ($result_local && $result_local->num_rows > 0) {
    $row = $result_local->fetch_assoc();
    $alerta_max = (float)$row['RuidoMaxAlerta'];
}
$conn->close();

// 2. LIMITES DA NUVEM (CRÍTICO)
$critico_max = 100.0; // Default

// CORREÇÃO: Timeout de 3s
$conn_nuvem = mysqli_init();
$conn_nuvem->options(MYSQLI_OPT_CONNECT_TIMEOUT, 3);
@$conn_nuvem->real_connect('194.210.86.10', 'aluno', 'aluno', 'maze');

if (!$conn_nuvem->connect_error) {
    $sql_nuvem = "SELECT normalnoise, noisevartoleration FROM setupmaze LIMIT 1";
    $result_nuvem = $conn_nuvem->query($sql_nuvem);

    if ($result_nuvem && $row_n = $result_nuvem->fetch_assoc()) {
        $critico_max = (float)$row_n['normalnoise'] + (float)$row_n['noisevartoleration'];
    }
    $conn_nuvem->close();
}

// 3. ENVIAR PARA O ANDROID
echo json_encode([
    "success" => true,
    "data" => [
        "maximo"      => $alerta_max, // Mantém compatibilidade com Android
        "alerta_max"  => $alerta_max,
        "critico_max" => $critico_max
    ]
]);
?>