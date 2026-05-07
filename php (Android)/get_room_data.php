<?php
include 'db_config.php';

// Como o Java está à espera de "Sala", "NumeroMarsamisEven" e "NumeroMarsamisOdd"
// não precisamos de dar "AS" (nomes falsos) no SELECT, usamos os nomes originais!
$sql = "SELECT Sala, NumeroMarsamisEven, NumeroMarsamisOdd FROM ocupacaolabirinto WHERE IDSimulacao = (SELECT IDSimulacao FROM simulacao WHERE Estado = '1' LIMIT 1)";

$result = $conn->query($sql);
$rooms = [];

if ($result) {
    while($row = $result->fetch_assoc()) {
        // Forçamos a ser texto (string) porque o teu Java diz "private String numberEven;"
        $rooms[] = [
            "Sala" => (string)$row['Sala'],
            "NumeroMarsamisEven" => (string)$row['NumeroMarsamisEven'],
            "NumeroMarsamisOdd" => (string)$row['NumeroMarsamisOdd']
        ];
    }
    echo json_encode(["success" => true, "data" => $rooms]);
} else {
    echo json_encode(["success" => false, "message" => "Erro na consulta de salas."]);
}
?>