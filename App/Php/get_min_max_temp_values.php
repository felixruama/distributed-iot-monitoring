<?php
// Silencia os warnings para não corromper o JSON no Android
error_reporting(0);
header('Content-Type: application/json');

$response = array('success' => false, 'message' => '', 'data' => null);

$username = $_REQUEST['username'] ?? '';
$password = $_REQUEST['password'] ?? '';
$database = $_REQUEST['database'] ?? '';

// 1. LIGAÇÃO À VOSSA BD LOCAL (Para os limites de Alerta)
$host_local = 'mysql';
$conn_local = new mysqli($host_local, $username, $password, $database);

if ($conn_local->connect_error) {
    $response['message'] = "Erro de ligação local: " . $conn_local->connect_error;
    echo json_encode($response);
    exit;
}

$alerta_max = 35.0;
$alerta_min = 10.0;

// CORREÇÃO: Procurar a simulação mais recente, independente do estado
$sql_local = "SELECT TempMaxAlerta, TempMinAlerta FROM simulacao ORDER BY IDSimulacao DESC LIMIT 1";
$result_local = $conn_local->query($sql_local);
if ($result_local && $row = $result_local->fetch_assoc()) {
    $alerta_max = isset($row['TempMaxAlerta']) ? (float)$row['TempMaxAlerta'] : 35.0;
    $alerta_min = isset($row['TempMinAlerta']) ? (float)$row['TempMinAlerta'] : 10.0;
}
$conn_local->close();


// 2. LIGAÇÃO À BD DO PROFESSOR (Para os limites Críticos Reais)
$critico_max = 40.0;
$critico_min = 10.0;

// CORREÇÃO: Definir timeout de 3 segundos para a BD do professor não encravar o Android
$conn_nuvem = mysqli_init();
$conn_nuvem->options(MYSQLI_OPT_CONNECT_TIMEOUT, 3);
@$conn_nuvem->real_connect('194.210.86.10', 'aluno', 'aluno', 'maze');

if (!$conn_nuvem->connect_error) {
    $sql_nuvem = "SELECT normaltemperature, temperaturevarhightoleration, temperaturevarlowtoleration FROM setupmaze LIMIT 1";
    $result_nuvem = $conn_nuvem->query($sql_nuvem);

    if ($result_nuvem && $row_n = $result_nuvem->fetch_assoc()) {
        $critico_max = (float)$row_n['normaltemperature'] + (float)$row_n['temperaturevarhightoleration'];
        $critico_min = (float)$row_n['normaltemperature'] - (float)$row_n['temperaturevarlowtoleration'];
    }
    $conn_nuvem->close();
}

// 3. ENVIAR TUDO PARA O ANDROID
$response['success'] = true;
$response['data'] = array(
    "minimo" => $alerta_min,      // Mantém a chave antiga para não crashar o gráfico atual
    "maximo" => $alerta_max,      // Mantém a chave antiga para não crashar o gráfico atual
    "alerta_min"  => $alerta_min, // Novas chaves se quiseres desenhar mais 2 linhas no Android
    "alerta_max"  => $alerta_max,
    "critico_min" => $critico_min,
    "critico_max" => $critico_max
);

echo json_encode($response);
?>