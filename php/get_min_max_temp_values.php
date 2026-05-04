<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

$response = array('success' => false, 'message' => '', 'data' => null);

$username = $_REQUEST['username'] ?? '';
$password = $_REQUEST['password'] ?? '';
$database = $_REQUEST['database'] ?? '';

$host = 'mysql'; 
$conn = new mysqli($host, $username, $password, $database);

if ($conn->connect_error) {
    $response['message'] = "Erro de ligação: " . $conn->connect_error;
    echo json_encode($response);
    exit;
}

$sql = "SELECT TempMaxAlerta, TempMinAlerta FROM simulacao ORDER BY IDSimulacao DESC LIMIT 1";
$result = $conn->query($sql);

if ($result && $row = $result->fetch_assoc()) {
    $response['success'] = true;
    $response['data'] = array(
        "minimo" => isset($row['TempMinAlerta']) ? (float)$row['TempMinAlerta'] : 10.0,
        "maximo" => isset($row['TempMaxAlerta']) ? (float)$row['TempMaxAlerta'] : 35.0
    );
} else {
    $response['success'] = true; 
    $response['data'] = array("minimo" => 10.0, "maximo" => 35.0);
}

$conn->close();
echo json_encode($response);
?>