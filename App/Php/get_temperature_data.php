<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

// Estrutura padrão para o Android não crashar[cite: 7]
$response = array('success' => false, 'message' => '', 'data' => array());

$username = $_REQUEST['username'] ?? '';
$password = $_REQUEST['password'] ?? '';
$database = $_REQUEST['database'] ?? '';

if (empty($username) || empty($password) || empty($database)) {
    $response['message'] = 'Preencha todos os campos.';
    echo json_encode($response);
    exit;
}

$host = 'mysql'; 
// AQUI ESTÁ A MAGIA DO PROFESSOR: Usar os dados da App para ligar![cite: 7]
$conn = new mysqli($host, $username, $password, $database);

if ($conn->connect_error) {
    $response['message'] = "Erro de conexão: " . $conn->connect_error;
    echo json_encode($response);
    exit;
}

// A nossa query que sabemos que funciona bem com os nomes corretos
$sql = "SELECT IDTemperatura as idtemperatura, Temperatura as temperatura FROM temperatura ORDER BY IDTemperatura ASC";
$result = $conn->query($sql);

if ($result) {
    $tempData = array();
    while ($row = $result->fetch_assoc()) {
        // Forçar a ser número (int/float) para o Java não reclamar
        $tempData[] = [
            "idtemperatura" => (int)$row['idtemperatura'],
            "temperatura" => (float)$row['temperatura']
        ];
    }
    
    $response['success'] = true;
    $response['data'] = $tempData;
    $response['message'] = 'Dados de temperatura carregados com sucesso.';
} else {
    $response['message'] = "Erro na query: " . $conn->error;
}

$conn->close();
echo json_encode($response);
?>