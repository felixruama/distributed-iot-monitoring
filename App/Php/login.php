<?php
// O db_config já faz a verificação de segurança máxima.
include 'db_config.php';

// SE O CÓDIGO CHEGOU AQUI, A PASSWORD ESTÁ CORRETA!
$user_login = $_REQUEST['username']; 

// Já não precisamos da SP_ValidarLogin! Vamos apenas buscar a Equipa diretamente.
$sql = "SELECT Equipa FROM utilizador WHERE Email = '$user_login'";
$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    // Envia o JSON perfeito de volta para o Android com a Equipa
    echo json_encode(["success" => true, "IDGrupo" => (int)$row['Equipa']]);
} else {
    // Caso raro de o user existir no MySQL mas ter sido apagado da tabela
    echo json_encode(["success" => false, "message" => "Erro: Conta sem perfil registado."]);
}

$conn->close();
?>
