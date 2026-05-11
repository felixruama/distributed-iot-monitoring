<?php
include 'db_config.php';

// Lê os parâmetros enviados pelo Android
$user = $_GET['username'];
$pass = $_GET['password'];
$db = $_GET['database'];

// AQUI ESTÁ A MAGIA: Os "AS" agora são IGUAIS aos @SerializedName do Java
$sql = "SELECT 
            ID as id, 
            Msg as msg, 
            Hora as hora, 
            Leitura as leitura, 
            Sensor as sensor, 
            TipoAlerta as tipoalerta 
        FROM mensagens 
        ORDER BY Hora DESC 
        LIMIT 50";

$result = $conn->query($sql);
$data = [];

if ($result) {
    while($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    echo json_encode(["success" => true, "data" => $data]);
} else {
    echo json_encode(["success" => false, "message" => "Erro na consulta de mensagens."]);
}
?>